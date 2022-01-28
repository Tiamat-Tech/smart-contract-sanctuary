/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.7 <0.9.0;

contract Calculator {
    function add(uint a, uint b) external pure returns(uint) {
        return a + b;
    }

    function mul(uint a, uint b) external pure returns(uint) {
        return a * b;
    }
}