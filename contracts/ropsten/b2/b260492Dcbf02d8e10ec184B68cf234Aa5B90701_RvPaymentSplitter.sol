// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract RvPaymentSplitter is PaymentSplitter {
    event PaymentReceived(address from, uint256 amount, string orderId);

    constructor(address[] memory payees, uint256[] memory shares_)
        PaymentSplitter(payees, shares_)
    {}

    function deposit(string calldata orderId) external payable {
        emit PaymentReceived(_msgSender(), msg.value, orderId);
    }
}