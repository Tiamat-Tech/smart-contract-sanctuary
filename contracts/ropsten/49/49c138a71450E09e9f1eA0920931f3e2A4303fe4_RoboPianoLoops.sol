// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RoboPianoLoops is ERC721Enumerable, Ownable {
  string public ALL_MP3_HASH =
    "c0791bc8bb1737c1524c1738b0544408a5e01a0bcd77eebb65b6fdcf30d388d8";

  string public BASE_URI =
    "https://ipfs.io/ipfs/QmNuHfqZexQWdHJDPfDCdaiqhAihodSLJFN9gzcBxJB9Eh/";

  uint256 public constant MAX_TOKENS = 16; // TODO

  uint256 public price = 0.025 * 10**18; // 0.025 Ether

  bool public isSaleActive = false;

  constructor() ERC721("RoboPianoLoops", "RPLOOP") {
    reserveToken(msg.sender, 1);
  }

  function reserveToken(address _to, uint256 tokenId) public onlyOwner {
    require(tokenId < MAX_TOKENS, "Invalid tokenId");
    _safeMint(_to, tokenId);
  }

  function mint(uint256 tokenId) public payable {
    require(isSaleActive, "Sale is not active");
    require(msg.value >= price, "Ether value sent is not correct");
    reserveToken(msg.sender, tokenId);
  }

  function flipSaleStatus() public onlyOwner {
    isSaleActive = !isSaleActive;
  }

  function setPrice(uint256 _newPrice) public onlyOwner {
    price = _newPrice;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return BASE_URI;
  }
}