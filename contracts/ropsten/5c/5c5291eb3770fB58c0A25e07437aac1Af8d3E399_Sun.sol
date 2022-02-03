// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract Sun is ERC20, ERC20Detailed {

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    )   public 
    ERC20Detailed(name, symbol, decimals) {
        _mint(msg.sender, 1000000000000000000000000000);
    }
}