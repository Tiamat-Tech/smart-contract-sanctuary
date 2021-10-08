// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract NFT is ERC721 {
  uint256 tokenId;
  constructor() ERC721("Sufi Token", "SFT") {
    tokenId = 0;
  }

  function mint(string memory  data) public {
    uint256 currentTokenId = tokenId++;
    _safeMint(msg.sender, currentTokenId, bytes(data));
  }
}