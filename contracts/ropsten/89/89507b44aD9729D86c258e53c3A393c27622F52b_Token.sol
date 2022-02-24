// SPDX-License-Identifier: No license

pragma solidity 0.8.10;

import "./utils/ERC20.sol";

contract Token is ERC20 {
  constructor(uint256 supply) ERC20("name", "TESTP") {
    _mint(msg.sender, supply);
  }
}