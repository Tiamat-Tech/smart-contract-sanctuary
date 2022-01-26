// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./HasSale.sol";


/**
 * @notice FixedPriceSaleOfCollection is a fixed-price sale of all tokens in a collection
 *
 * this implementation varies in the following manner:
 *  1. buyer can buy any amount of any token (tokenId) in the collection, as long as the seller own such amount
 *  2. the sale starts immediately and is not time-bounded
 *  3. seller can always cancel the sale
 */
contract FixedPriceSaleOfCollection is HasSale {

    event Created(uint indexed id, address indexed collection, address seller);
    event Canceled(uint indexed id, address indexed collection);

    function createSale(address collection, uint price) external returns (uint) {
        uint id = super.createSale(collection);
        sales[id] = Sale(collection, 0, msg.sender, price);
        emit Created(id, collection, msg.sender);
        return id;
    }

    function buy(uint saleId, uint tokenId, uint amount) external payable {
        super.buyToken(saleId, tokenId, amount);
    }

    function cancel(uint saleId) public virtual override {
        emit Canceled(saleId, sales[saleId].collection);
        super.cancel(saleId);
    }
}