// SPDX-License-Identifier: NOLICENSE

pragma solidity 0.8.0;

import './ERC20.sol';

contract PIIC is ERC20 {
  constructor() ERC20("PIIC Token", "PIIC") {
    _mint(msg.sender, 100000);
  }
}