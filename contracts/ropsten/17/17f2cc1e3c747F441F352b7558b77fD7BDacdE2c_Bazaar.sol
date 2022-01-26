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
 *  3. an offer involves an escrow and is time-bounded, after which the escrow can be retrieved
 *  4. the seller can always cancel the sale
 */
contract Bazaar is HasSale {
    using Address for address payable;

    event Created(uint indexed id, address indexed collection, uint indexed tokenId, address seller);
    event OfferMade(uint indexed id, address buyer, uint amount, uint price, uint endsAt);
    event OfferRetracted(uint indexed id, address buyer, uint amount, uint price);
    event Canceled(uint indexed id, address indexed collection, uint indexed tokenId);

    struct Offer {
        address buyer;
        uint amount;
        uint price;
        uint endsAt;
    }

    mapping(address => mapping(uint => Offer)) public offers; // buyer => sale-id => Offer

    function createSale(address collection, uint tokenId, uint price) external returns (uint) {
        uint id = super.createSale(collection);
        sales[id] = Sale(collection, tokenId, msg.sender, price);
        emit Created(id, collection, tokenId, msg.sender);
        return id;
    }

    function makeOffer(uint saleId, uint amount, uint price, uint acceptancePeriod) external payable costs(amount * price) exists(saleId) {
        address buyer = msg.sender;
        require(offers[buyer][saleId].amount == 0, "cannot make another offer, nor modify an existing one");
        uint endsAt = block.timestamp + acceptancePeriod;
        offers[buyer][saleId] = Offer(buyer, amount, price, endsAt);
        emit OfferMade(saleId, buyer, amount, price, endsAt);
    }

    function retractOffer(uint saleId) external {
        address buyer = msg.sender;
        Offer storage offer = offers[buyer][saleId];
        require(offer.amount != 0, "no such offer");
        require(sales[saleId].seller == address(0) || block.timestamp >= offer.endsAt, "cannot retract offer during acceptance-period");
        payable(buyer).sendValue(offer.amount * offer.price); //refund
        emit OfferRetracted(saleId, buyer, offer.amount, offer.price);
        delete offers[buyer][saleId];
    }

    function acceptOffer(uint saleId, address buyer) external exists(saleId) only(sales[saleId].seller) {
        Sale storage sale = sales[saleId];
        Offer storage offer = offers[buyer][saleId];
        address seller = sale.seller;
        uint balance = IERC1155(sale.collection).balanceOf(seller, sale.tokenId);
        if (balance < offer.amount) revert InsufficientTokens(saleId, offer.amount, balance);
        exchange(saleId, sale.collection, sale.tokenId, offer.amount, offer.price, seller, buyer);
        delete offers[buyer][saleId];
        delete sales[saleId];
    }

    function cancel(uint saleId) public virtual override {
        emit Canceled(saleId, sales[saleId].collection, sales[saleId].tokenId);
        super.cancel(saleId);
    }
}