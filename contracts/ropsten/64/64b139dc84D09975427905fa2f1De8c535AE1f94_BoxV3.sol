// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract BoxV3 {
    uint public value;

    // function initialze(uint val) external {
    //     value=val;
    // }

      function multiply() external {
        value*=2;
    }
}