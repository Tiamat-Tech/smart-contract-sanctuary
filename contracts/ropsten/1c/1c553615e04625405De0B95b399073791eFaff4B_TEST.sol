// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './token/ERC20/ERC20.sol';

contract TEST is ERC20 {
  constructor() ERC20("TEST token", "TEST") {
    _mint(msg.sender, 1000 * (10 ** 18));
  }
}