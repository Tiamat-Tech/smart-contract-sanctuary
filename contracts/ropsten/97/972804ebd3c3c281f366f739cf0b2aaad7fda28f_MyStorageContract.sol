/**
 *Submitted for verification at Etherscan.io on 2021-12-08
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.7;

contract MyStorageContract {
    string name;

    constructor(string memory _name) {
        name = _name;
    }

    function set(string memory _name) public {
        name = _name;
    } 

    function get() public view returns(string memory) {
        return name;
    }
}