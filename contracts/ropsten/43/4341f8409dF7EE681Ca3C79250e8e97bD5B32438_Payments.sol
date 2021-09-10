// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/utils/Address.sol';

contract Payments {
    address payable public owner;

    event PaymentSent(address receiver, uint256 amount);

    constructor() public {
        owner = msg.sender;
    }

    function payOwner() public payable {
        Address.sendValue(owner, msg.value);
        emit PaymentSent(owner, msg.value);
    }

    function pay(address payable receiver) public payable {
        Address.sendValue(receiver, msg.value);
        emit PaymentSent(receiver, msg.value);
    }
}