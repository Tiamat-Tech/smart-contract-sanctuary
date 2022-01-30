//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlockFriendNFT is Ownable, ERC721Enumerable {
  constructor() ERC721("BlockFriendNFT", "BFNFT") {
      _baseTokenURI = "https://blockfriend-website.herokuapp.com/metadata/";
  }

  string public _baseTokenURI;

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseTokenURI;
  }

  function setBaseURI(string calldata baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  function mint(uint256 quantity) external onlyOwner {
    uint currentIndex = totalSupply();
    for (uint i = 0; i < quantity; i++) {
      _safeMint(msg.sender, currentIndex + i);
    }
  }

  function burn(uint256 tokenId) external onlyOwner {
    _burn(tokenId);
  }
}