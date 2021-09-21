// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract ClumsySquirrelPaymentSplitter is PaymentSplitter {
    // Addresses of payees
    address[] private _CSPayees = [
        0x23377d974d85C49E9CB6cfdF4e0EED1C0Fc85E6A,
        0x85F68F10d3c13867FD36f2a353eeD56533f1C751
    ];
    // Number of shares allocated per address in this contract.  In same order as _CSPayees
    uint256[] private _CSShares = [1, 2];

    constructor() public PaymentSplitter(_CSPayees, _CSShares) {}
}