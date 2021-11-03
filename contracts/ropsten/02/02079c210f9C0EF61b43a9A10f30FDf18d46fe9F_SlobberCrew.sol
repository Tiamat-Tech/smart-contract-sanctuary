// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/*
Contract TODO:
  - reveal reveal Time Stamp
  - startingIndex

Other todo:
  - changed logic around image generation rules
  -

Once full asset set is available
  - generate provenance hash set and post to website
  - post contract for review (verified)
  - update image generation logic
*/

// TODO test transfer behavior, use optimizer
contract SlobberCrew is ERC721, ERC721Enumerable, Ownable {
  using SafeMath for uint256;

  // set relevant contract values
  string public constant TOKEN_NAME = "Slobber Crew";
  string public constant TOKEN_SYMBOL = "SBC";
  uint16 public constant MAX_TOKENS = 10000;
  uint8 public constant MAX_TOKEN_PURCHASE = 40;
  uint public constant TOKEN_PRICE = 500000000000000; // 0.05 ETH public sale

  // state values
  string public provenanceHash;
  string public baseURI;
  uint8 public saleState; // 0 inactive, 1 presale, 2 public sale
  uint256 public revealTimestamp;
  uint256 public startingIndex;


  constructor() ERC721(TOKEN_NAME, TOKEN_SYMBOL) {
  }


  function setProvenanceHash(string memory provenanceHash_) public onlyOwner {
    require(bytes(provenanceHash).length == 0,
      "Provenance hash cannot be changed once set");

    provenanceHash = provenanceHash_;
  }


  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }


  function setBaseURI(string memory baseURI_) public onlyOwner {
    baseURI = baseURI_;
  }


  function reserveTokens(uint8 numTokens) public onlyOwner {
    uint totalSupply = totalSupply();

    // shouldn't be an issue as reserve should be set aside prior to sale
    // but keep here to be safe
    require((totalSupply + numTokens) <= MAX_TOKENS,
      "Reserve would exceed max supply of tokens");

    for (uint8 i; i < numTokens; i++) {
      _safeMint(msg.sender, totalSupply + i);
    }
  }


  function setSaleState(uint8 saleState_) public onlyOwner {
    saleState = saleState_;
  }


  function setRevealTimestamp(uint256 revealTimestamp_) public onlyOwner {
    revealTimestamp = revealTimestamp_;
  }


  function setStartingIndex() public onlyOwner {
    require(startingIndex == 0, "Starting index is already set");

    startingIndex = uint(blockhash(block.number)) % MAX_TOKENS;

    // safety check to prevent default sequence
    if (startingIndex == 0) {
      startingIndex = 1000;
    }
  }


  function withdraw() public onlyOwner {
    uint balance = address(this).balance;
    payable(msg.sender).transfer(balance);
  }


  function mintTokens(uint numTokens) public payable {
    require(saleState > 0, "Sale must be active to mint token");
    require(numTokens <= MAX_TOKEN_PURCHASE, "Can only mint 40 tokens at a time");
    require(TOKEN_PRICE.mul(numTokens) <= msg.value, "Ether value sent is not correct");

    uint totalSupply = totalSupply();
    require((totalSupply + numTokens) <= MAX_TOKENS, "Purchase would exceed max supply of tokens");

    uint8 mintedTokens;
    for(mintedTokens; mintedTokens < numTokens; mintedTokens++) {
      _safeMint(msg.sender, totalSupply + mintedTokens);
    }

    if (startingIndex == 0 && ((totalSupply + mintedTokens) == MAX_TOKENS ||
      block.timestamp >= revealTimestamp)) {

      setStartingIndex();
    }
  }


  // The following functions are overrides required by Solidity.
  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal override(ERC721, ERC721Enumerable)
  {
    super._beforeTokenTransfer(from, to, tokenId);
  }


  function supportsInterface(bytes4 interfaceId) public view
    override(ERC721, ERC721Enumerable) returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}