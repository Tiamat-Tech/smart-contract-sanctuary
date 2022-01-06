//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Shoes is ERC721URIStorage {
  address contractAddress;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdTracker;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  function mintNFT(string memory tokenURI) public {
    // get token id
    uint256 tokenId = _tokenIdTracker.current();

    // mint for person that called function
    _safeMint(_msgSender(), tokenId);

    // set token uri based on parameter passed
    _setTokenURI(tokenId, tokenURI);

    // increments token id count
    _tokenIdTracker.increment();
  }
}