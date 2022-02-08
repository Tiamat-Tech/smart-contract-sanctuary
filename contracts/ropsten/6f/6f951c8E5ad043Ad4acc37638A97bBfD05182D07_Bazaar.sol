// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/Address.sol";
import "./HasSale.sol";


/**
 * a Bazaar is an interactive marketplace where:
 * seller lists, potential buyer makes an offer, which the seller in turn either accepts or ignores
 *
 * this implementation varies in the following manner:
 *  1. the sale starts immediately and is not time-bounded
 *  2. a (potential) buyer can buy any amount of the tokenId, as long as the seller own such amount
 *  3. an offer involves an escrow and is not time-bounded
 *  4. an offer is accepted automatically if it is at the asking price or above
 *  5. the buyer can retract the offer at any time
 *  6. the buyer can update the offer at any time
 *  7. the seller can cancel the sale at any time
 */
contract Bazaar is HasSale {
    using Address for address payable;

    event Created(uint id, address collection, uint tokenId, uint amount, address seller);
    event OfferMade(uint id, address buyer, uint tokenId, uint amount, uint price);
    event OfferRetracted(uint id, address buyer, uint tokenId, uint amount, uint price);
    event Canceled(uint id, address collection, uint tokenId);

    struct Offer {
        address buyer;
        uint tokenId;
        uint amount;
        uint price; // per unit
    }

    mapping(address => mapping(uint => mapping(uint => Offer))) public offers; // buyer => sale-id => tokenId => Offer

    function createSale(address collection, uint tokenId, uint amount, uint price) external returns (uint) {
        uint id = super.createSale(collection);
        sales[id] = Sale(collection, tokenId, amount, msg.sender, price);
        emit Created(id, collection, tokenId, amount, msg.sender);
        return id;
    }

    function makeOffer(uint saleId, uint tokenId, uint amount, uint price) external payable exists(saleId) {
        address buyer = msg.sender;
        Sale storage sale = sales[saleId];
        require(sale.tokenId == ALL || sale.tokenId == tokenId, "token id offered for is not for sale");
        require(sale.amount == ALL || sale.amount >= amount, "desired amount exceeds amount sold limit");
        uint totalValue = retractPrevious(buyer, saleId, tokenId) + msg.value;
        if (totalValue < amount * price) revert InsufficientFunds(amount * price, totalValue);
        uint toBeReturned = totalValue - amount * price;
        offers[buyer][saleId][tokenId] = Offer(buyer, tokenId, amount, price);
        emit OfferMade(saleId, buyer, tokenId, amount, price);
        if (price >= sale.price) acceptOffer(saleId, sale, offers[buyer][saleId][tokenId]);
        if (toBeReturned > 0) payable(msg.sender).sendValue(toBeReturned);
    }

    function retractOffer(uint saleId, uint tokenId) external {
        uint toBeReturned = retractPrevious(msg.sender, saleId, tokenId);
        require(toBeReturned != 0, "no such offer");
        payable(msg.sender).sendValue(toBeReturned);
    }

    function retractPrevious(address buyer, uint saleId, uint tokenId) private returns (uint){
        Offer storage offer = offers[buyer][saleId][tokenId];
        if (offer.amount == 0) return 0;
        uint amount = offer.amount * offer.price;
        emit OfferRetracted(saleId, buyer, tokenId, offer.amount, offer.price);
        delete offers[buyer][saleId][tokenId];
        return amount;
    }

    function acceptOffer(uint saleId, address buyer, uint tokenId, uint price) external exists(saleId) only(sales[saleId].seller) {
        Sale storage sale = sales[saleId];
        Offer storage offer = offers[buyer][saleId][tokenId];
        require(offer.price == price, "offer has changed");
        acceptOffer(saleId, sale, offer);
    }

    function acceptOffer(uint saleId, Sale storage sale, Offer storage offer) private {
        uint balance = IERC1155(sale.collection).balanceOf(sale.seller, offer.tokenId);
        uint available = (sale.amount > balance || sale.tokenId == 0) ? balance : sale.amount;
        if (available < offer.amount) revert InsufficientTokens(saleId, offer.amount, available);
        exchange(saleId, sale.collection, offer.tokenId, offer.amount, offer.price, sale.seller, offer.buyer);
        if (sale.tokenId != 0) {
            sale.amount -= offer.amount;
            if (sale.amount == 0) delete sales[saleId];
        }
        delete offers[offer.buyer][saleId][offer.tokenId];
    }

    function cancel(uint saleId) public virtual override {
        emit Canceled(saleId, sales[saleId].collection, sales[saleId].tokenId);
        super.cancel(saleId);
    }
}