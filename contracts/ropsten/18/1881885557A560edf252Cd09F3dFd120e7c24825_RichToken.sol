// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RichToken is ERC20 {
  constructor(uint256 _amount) ERC20("Rich", "RICH") {
    _mint(msg.sender, _amount * 10 ** decimals());
  }
}