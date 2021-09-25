// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract ClumsySquirrelPaymentSplitter is PaymentSplitter {
    // Addresses of payees [mo-1, mo-2, thanh]
    address[] private _CSPayees = [
        0x712d7b04480aA4CB2f6b487262A211F8f44fBDeb,
        0xD258f822fF32F192DBDa86BE26c0346B616DEc1B,
        0x23377d974d85C49E9CB6cfdF4e0EED1C0Fc85E6A
    ];
    // mo-1 allocated 1 share, mo-2 allocated 1 share, thanh allocated 1 share
    uint256[] private _CSShares = [1, 1, 1];

    constructor() public PaymentSplitter(_CSPayees, _CSShares) {}
}