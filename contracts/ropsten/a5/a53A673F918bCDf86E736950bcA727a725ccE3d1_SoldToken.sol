// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SoldToken is ERC20, ERC20Burnable {
    constructor(uint256 initialSupply) ERC20("Sold Token", "SLDT") {
        _mint(msg.sender, initialSupply);
    }
}