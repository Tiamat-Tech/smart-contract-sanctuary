//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

import "hardhat/console.sol";

contract Counter {
    uint256 public number = 2;

    function increment() public {
        number++;
        console.log("number is %d", number);
    }

    function decrement() public {
        number--;
        console.log("number is %d", number);
    }

    function backToZero() public {
        number = 0;
        console.log("number is %d", number);
    }
}