// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract C is ERC20 {
  constructor() ERC20("C", "C") {
    _mint(msg.sender, 100 ether); // ether just means 18 decimals
  }
}