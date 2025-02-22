// contracts/YangToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";

contract YangToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("YangToken", "YAT") {
        _mint(msg.sender, initialSupply);
    }
}