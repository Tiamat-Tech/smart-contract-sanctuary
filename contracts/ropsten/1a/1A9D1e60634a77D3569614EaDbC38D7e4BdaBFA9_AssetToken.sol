//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AssetToken is ERC20 {
  constructor(
    uint256 totalSupply_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_) ERC20(name_, symbol_) {
      _mint(msg.sender, totalSupply_);      
    }
}