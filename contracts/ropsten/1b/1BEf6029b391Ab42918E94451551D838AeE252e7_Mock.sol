// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Mock is ERC20, Ownable {
  constructor(
    address _owner,
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) Ownable() {
    transferOwnership(_owner);
    _mint(_owner, 10**decimals() * (10**9));
  }
}