//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./ERC20WithDecimals.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AssetToken is ERC20WithDecimals {
  constructor(
    uint256 totalSupply_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_
  ) ERC20(name_, symbol_) ERC20WithDecimals(decimals_) {
    _mint(msg.sender, totalSupply_);
    // console.log("Deploying a Greeter with greeting:", _greeting);
    // greeting = _greeting;
  }

  // function greet() public view returns (string memory) {
  //   return greeting;
  // }

  // function setGreeting(string memory _greeting) public {
  //   console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
  //   greeting = _greeting;
  // }
}