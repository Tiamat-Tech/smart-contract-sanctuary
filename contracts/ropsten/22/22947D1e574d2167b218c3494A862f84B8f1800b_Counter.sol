/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

contract Counter {
    uint public count;

    // Function to get the current count
    function get() public view returns (uint) {
        return count;
    }

    // Function to increment count by 1
    function inc() public {
        count += 2;
    }

    // Function to decrement count by 1
    function dec() public {
        count -= 2;
    }
}