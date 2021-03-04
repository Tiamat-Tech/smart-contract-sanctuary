// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import 'openzeppelin-solidity/contracts/token/ERC721/ERC721.sol';

contract TokenERC721 is ERC721 {
  constructor(
    string memory _name,
    string memory _symbol,
    uint _tokenId
  ) ERC721(_name, _symbol) {
    _mint(msg.sender, _tokenId);
  }
}