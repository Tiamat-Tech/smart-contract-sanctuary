// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract QuickTokensV8 is ERC721Enumerable, Ownable {

  string private constant BASE_URI
    = "ipfs://QmT3xBjTzKHbYdmdpqx6ySThdtnck8c9vwCQPu6Qevuzf6/";
  bool private isSaleActive = true;
  uint256 private constant MAX_NUM_TOKENS = 100;
  uint256 private price = 1000000000000000; // 0.001 Ether

  constructor() ERC721("QuickTokensV8", "QUICKV8") {}

  function _baseURI() internal pure override returns (string memory) {
    return BASE_URI;
  }

  function flipSaleStatus() public onlyOwner {
    isSaleActive = !isSaleActive;
  }

  function getBaseURI() public pure returns (string memory) {
    return _baseURI();
  }

  function getIsSaleActive() public view returns (bool) {
    return isSaleActive;
  }

  function getMaxNumTokens() public pure returns (uint256) {
    return MAX_NUM_TOKENS;
  }

  function getNumTokensAvailableToMint() public view returns (uint256) {
    return MAX_NUM_TOKENS - totalSupply();
  }

  function getPrice() public view returns (uint256) {
    return price;
  }

  function mintTokens(uint256 _quantity) public payable {
    uint256 numTokensMinted = totalSupply();

    require(isSaleActive, "Sale is not active" );
    require(
      numTokensMinted + _quantity <= MAX_NUM_TOKENS,
      "Exceeds number of tokens available for minting"
    );
    require(msg.value >= price * _quantity, "Insufficient payment");
    
    for (uint256 i = 0; i < _quantity; i++) {
      _safeMint(msg.sender, numTokensMinted + i + 1);
    }
  }

  function mintReserveTokens(uint256 _quantity) public onlyOwner {
    uint256 numTokensMinted = totalSupply();

    require(
      numTokensMinted + _quantity <= MAX_NUM_TOKENS,
      "Exceeds number of tokens available for minting"
    );
    
    for (uint256 i = 0; i < _quantity; i++) {
      _safeMint(msg.sender, numTokensMinted + i + 1);
    }
  }

  function setPrice(uint256 _price) public onlyOwner {
    price = _price;
  }

  function withdraw() public onlyOwner {
    payable(msg.sender).transfer(address(this).balance);
  }
}