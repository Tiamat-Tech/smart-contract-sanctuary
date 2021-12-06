// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20, Ownable {
  constructor() ERC20("mock", "MOCK") Ownable() {
    _mint(_msgSender(), 10**decimals() * (10**9));
  }
}