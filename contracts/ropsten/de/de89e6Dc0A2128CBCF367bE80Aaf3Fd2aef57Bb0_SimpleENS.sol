/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract SimpleENS {
    mapping ( string => address ) public registry;

    function registerDomain(string memory domain) public {
        require(registry[domain] == address(0));
        registry[domain] = msg.sender;
    }
}