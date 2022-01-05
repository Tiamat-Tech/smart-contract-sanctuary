//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BDERC20 is ERC20 {
    constructor (string memory _name, string memory _symbol) ERC20(_name, _symbol) {}
}