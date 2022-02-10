// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC1155 is ERC1155 {
  constructor() ERC1155("") {}

  function claim(uint256 amount, uint256 id) external {
    _mint(msg.sender, id, amount, "");
  }
}