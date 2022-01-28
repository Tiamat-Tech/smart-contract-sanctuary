// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

contract BoxV2 {
    uint public value;

    // function initialze(uint val) external {
    //     value=val;
    // }

      function inc() external {
        value+=1;
    }


}