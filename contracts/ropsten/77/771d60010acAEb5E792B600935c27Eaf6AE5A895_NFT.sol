// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() ERC721("NFT", "NFT") {}

  function mintToken(string memory tokenURI) public returns (uint256) {
    _tokenIds.increment();
    uint256 newId = _tokenIds.current();

    _mint(msg.sender, newId);
    _setTokenURI(newId, tokenURI);

    return newId;
  }

  function burn(uint256 tokenId) external {
    require(
      _isApprovedOrOwner(msg.sender, tokenId),
      "caller is not owner nor approved"
    );
    _burn(tokenId);
  }

  // Getters

  function totalSupply() public view returns (uint256) {
    return _tokenIds.current();
  }

  function getMyTokens() public view returns (string[] memory) {
    uint256 totalItems = totalSupply();
    uint256 tokenCount = balanceOf(msg.sender);
    uint256 currentIndex = 0;

    string[] memory items = new string[](tokenCount);
    for (uint256 i = 0; i < totalItems; i++) {
      if (ownerOf(i + 1) == msg.sender) {
        uint256 currentId = i + 1;
        string memory currentItem = tokenURI(currentId);
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }
}