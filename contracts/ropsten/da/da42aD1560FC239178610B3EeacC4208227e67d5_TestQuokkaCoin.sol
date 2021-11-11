// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol"; 

contract TestQuokkaCoin is ERC20 {
    constructor(uint256 initialSupply) ERC20("Test Quokka Token", "TQOK", 18) {
        _mint(msg.sender, initialSupply);
    }
}