pragma solidity ^0.8.7;

// SPDX-License-Identifier: MIT

import "ERC20.sol";
import "SafeMath.sol";

contract ERC20token is ERC20 {
    constructor(uint256 initialSupply) ERC20("TToken", "TTK") {
        _mint(msg.sender, initialSupply);
    }
}