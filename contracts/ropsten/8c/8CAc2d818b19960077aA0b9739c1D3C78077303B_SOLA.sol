// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract SOLA is ERC20Burnable, Ownable {
  
  constructor(
    string memory name,
    string memory symbol
  ) ERC20(name, symbol) {
    _mint(msg.sender, 1000000000 * 10 ** 18);
  }

}