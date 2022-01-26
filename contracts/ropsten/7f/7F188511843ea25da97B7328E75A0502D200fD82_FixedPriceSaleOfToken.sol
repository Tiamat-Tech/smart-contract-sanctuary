// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./HasSale.sol";


/**
 * @notice FixedPriceSaleOfToken is a fixed-price sale of a specific collection/tokenId
 *
 * this implementation varies in the following manner:
 *  1. buyer can buy any amount of the tokenId, as long as the seller own such amount
 *  2. the sale starts immediately and is not time-bounded
 *  3. seller can always cancel the sale
 */
contract FixedPriceSaleOfToken is HasSale {

    event Created(uint indexed id, address indexed collection, uint indexed tokenId, address seller);
    event Canceled(uint indexed id, address indexed collection, uint indexed tokenId);

    function createSale(address collection, uint tokenId, uint price) external returns (uint) {
        uint id = super.createSale(collection);
        sales[id] = Sale(collection, tokenId, msg.sender, price);
        emit Created(id, collection, tokenId, msg.sender);
        return id;
    }

    function buy(uint saleId, uint amount) external payable {
        super.buyToken(saleId, sales[saleId].tokenId, amount);
    }

    function cancel(uint saleId) public virtual override {
        emit Canceled(saleId, sales[saleId].collection, sales[saleId].tokenId);
        super.cancel(saleId);
    }
}