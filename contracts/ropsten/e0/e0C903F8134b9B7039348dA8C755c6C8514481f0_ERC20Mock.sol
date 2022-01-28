// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 decimal;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        _mint(msg.sender, 2 ** 256 - 1);
        decimal = 18;
    }

    function decimals() public view override returns (uint8) {
        return decimal;
    }

    function setDecimals(uint8 _decimals) external {
        decimal = _decimals;
    }
}