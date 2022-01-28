// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./ERC20PresetFixedSupply.sol";

contract MyName is ERC20PresetFixedSupply {
  constructor() ERC20PresetFixedSupply("FFF", "FFFAA", 1 * (10**9) * (10**18), 0x4368c224665CC098A70FE4C1322218ae03511395) {}
}