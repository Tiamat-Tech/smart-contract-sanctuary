/*
away from keyboard... ($AFK)
Website = <website>
Telegram = <telegram>
Twitter = <twitter>
*/

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./ERC20.sol";

contract AFK is ERC20 {
  constructor(string memory name, string memory symbol, uint256 totalSupply) public ERC20(name, symbol) {
    _mint(msg.sender, totalSupply * (10 ** 18));
  }
}