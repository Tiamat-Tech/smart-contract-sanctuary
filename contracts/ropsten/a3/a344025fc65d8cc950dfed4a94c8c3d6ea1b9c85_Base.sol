/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-2.0

pragma solidity >=0.7.0 <0.9.0;


contract Base {
    mapping (address=>address) users;
    mapping (address=>address) merchants;

    function getUser(address addr) external view returns (address) {
        return users[addr];
    }

    function addUser (address user, address addr) external {
        users[user] = addr;
    }

    function addMerchant (address merchant, address addr) external {
        merchants[merchant] = addr;
    }
    function getMerchant(address addr) external view returns (address) {
        return merchants[addr];
    }
}