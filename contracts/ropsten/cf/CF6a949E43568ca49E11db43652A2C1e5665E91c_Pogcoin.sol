//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pogcoin is ERC20 {
    constructor(uint256 initialSupply) ERC20("Pogcoin", "PAO") {
        _mint(msg.sender, initialSupply);
    }
}