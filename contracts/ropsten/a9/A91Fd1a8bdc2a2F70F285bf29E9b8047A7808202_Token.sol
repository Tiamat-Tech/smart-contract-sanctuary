// SPDX-License-Identifier: MIT

pragma solidity =0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
  constructor(uint256 amount) ERC20("Test Token", "TT2") {
    _mint(msg.sender, amount);
  }
}