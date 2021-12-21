//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract NFT is ERC1155("") {
  address public immutable owner;

  constructor(string memory uri_) {
    _setURI(uri_);
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner, "only owner can do this action");
    _;
  }

  function setURI(string memory uri_) external onlyOwner {
    _setURI(uri_);
  }

  function mint(address to, uint256 id) external onlyOwner {
   _mint(to, id, 1, "");
  }
}