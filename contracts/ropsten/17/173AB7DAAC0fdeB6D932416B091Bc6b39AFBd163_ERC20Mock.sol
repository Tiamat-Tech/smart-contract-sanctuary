//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {
  }

  function mint(uint256 amount) external {
    // require(amount == 0, string(abi.encodePacked(
    //     "mint: ",
    //     toString(abi.encodePacked(msg.sender))
    // )));

    _mint(msg.sender, amount);
  }
  
}