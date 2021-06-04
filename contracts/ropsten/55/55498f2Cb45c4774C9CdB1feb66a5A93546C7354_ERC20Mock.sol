// SPDX-License-Identifier: MIT

pragma solidity =0.7.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
  constructor(uint256 amount) ERC20("Test Token", "TT") {
    _mint(msg.sender, amount);
  }
}