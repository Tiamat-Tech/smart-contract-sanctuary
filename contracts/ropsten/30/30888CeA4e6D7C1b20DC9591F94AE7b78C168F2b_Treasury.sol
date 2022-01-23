// SPDX-License-Identifier: None
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract Treasury is PaymentSplitter {
    // share settings
    address[] private addressList = [
        0x94eF21BB900CaCC5fdAa521A034e420E02126800,
        0xD39b723259db6AEd5ee383dfC35d60974474837F
    ];
    uint256[] private shareList = [70, 30];

    uint256 private _numberOfPayees;

    constructor() payable PaymentSplitter(addressList, shareList) {
        _numberOfPayees = addressList.length;
    }

    function withdrawAll() external {
        require(address(this).balance > 0, "No balance to withdraw");

        for (uint256 i = 0; i < _numberOfPayees; i++) {
            release(payable(payee(i)));
        }
    }
}