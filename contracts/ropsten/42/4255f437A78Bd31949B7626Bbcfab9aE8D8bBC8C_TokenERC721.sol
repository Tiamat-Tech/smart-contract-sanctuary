// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import 'openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
contract TokenERC721 is ERC721URIStorage {

  constructor(
    string memory _name,
    string memory _symbol,
    string memory uri_,
    uint _tokenId
  ) ERC721(_name, _symbol) {
    _mint(msg.sender, _tokenId);
    _setTokenURI(_tokenId, uri_);
  }
}