// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol"; 

contract NewTestCoin is ERC20 {
    constructor(uint256 initialSupply) ERC20("NewTestCoin", "NTC", 0) {
        _mint(msg.sender, initialSupply);
    }
}