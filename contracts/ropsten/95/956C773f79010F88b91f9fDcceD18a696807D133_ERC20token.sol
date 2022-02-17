pragma solidity ^0.8.11;

// SPDX-License-Identifier: MIT

import "ERC20.sol";
import "SafeMath.sol";

contract ERC20token is ERC20 {
    constructor(uint256 initialSupply, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply);
    }
}