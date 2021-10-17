// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RoboPianoLoops is ERC721Enumerable, Ownable {
  string public ALL_MP3_HASH = "";

  function setHash(string memory h) public onlyOwner {
    ALL_MP3_HASH = h;
  }

  uint256 public MAX_TOKENS = 10;

  function setMaxTokens(uint256 n) public onlyOwner {
    require(n > MAX_TOKENS, "Unable to decrease supply");
    MAX_TOKENS = n;
  }

  uint256 public MAX_TOKENS_PER_PURCHASE = 5;

  function setMaxTokensPerPurchase(uint256 n) public onlyOwner {
    MAX_TOKENS_PER_PURCHASE = n;
  }

  string public BASE_URI = "";

  function setBaseUri(string memory s) public onlyOwner {
    BASE_URI = s;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return BASE_URI;
  }

  uint256 public PRICE_PER_TOKEN = 0.025 * 10**18; // 0.025 Ether

  function setPricePerToken(uint256 _newPrice) public onlyOwner {
    PRICE_PER_TOKEN = _newPrice;
  }

  bool public IS_SALE_ACTIVE = false;

  function setIsSaleActive(bool b) public onlyOwner {
    IS_SALE_ACTIVE = b;
  }

  constructor() ERC721("RoboPianoLoops", "RPLOOP") {}

  function _mintTokens(
    address _to,
    uint256 fromTokenId,
    uint256 toTokenId
  ) private {
    require(fromTokenId == totalSupply(), "Invalid range start");
    require(toTokenId < MAX_TOKENS, "Invalid range end");
    for (uint256 i = fromTokenId; i <= toTokenId; i++) {
      _safeMint(_to, i);
    }
  }

  function reserveTokens(
    address _to,
    uint256 fromTokenId,
    uint256 toTokenId
  ) public onlyOwner {
    _mintTokens(_to, fromTokenId, toTokenId);
  }

  function mint(uint256 fromTokenId, uint256 toTokenId) public payable {
    require(IS_SALE_ACTIVE, "Sale is not active");

    uint256 numBuying = 1 + (toTokenId - fromTokenId);

    require(
      numBuying <= MAX_TOKENS_PER_PURCHASE,
      "Exceeds MAX_TOKENS_PER_PURCHASE"
    );
    require(
      msg.value >= PRICE_PER_TOKEN * numBuying,
      "Insufficient ether sent"
    );

    _mintTokens(msg.sender, fromTokenId, toTokenId);
  }

  function totalSold() public view returns (uint256) {
    return totalSupply();
  }

  function withdraw() public onlyOwner {
    uint256 balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }
}