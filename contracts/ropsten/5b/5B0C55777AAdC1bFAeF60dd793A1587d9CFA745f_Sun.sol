// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract Sun is ERC20, ERC20Detailed {
    string public _name;
    string public _symbol;
    uint8 public _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals) public
    ERC20Detailed(name, symbol, decimals) {
        _name = name;
        _symbol = symbol;
        _decimals = decimals;
        _mint(msg.sender, 10000000000000000000);
    }
}