//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Shoes is ERC721URIStorage {
  address contractAddress;
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIdTracker;

  mapping(uint256 => uint256) public marketplaceStatus;
  uint256[] marketplaceStatusArray;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  // The function to mint the NFT
  function mintNFT(string memory _tokenURI, uint256 _marketplaceStatus) public {
    // get token id
    uint256 tokenId = _tokenIdTracker.current();

    // mint for person that called function
    _safeMint(_msgSender(), tokenId);

    // set token uri based on parameter passed
    _setTokenURI(tokenId, _tokenURI);

    // set the marketplace status
    marketplaceStatus[tokenId] = _marketplaceStatus;
    marketplaceStatusArray.push(_marketplaceStatus);

    // increments token id count
    _tokenIdTracker.increment();
  }

  // The function to get marketplaceStatus for a specific NFT
  function getMarketplaceStatus(uint256 _tokenId) public view returns (uint256) {
    return marketplaceStatus[_tokenId];
  }

  // The function to set marketplaceStatus for a specific NFT
  function setMarketplaceStatus(uint256 _tokenId) public {
    marketplaceStatus[_tokenId] = _tokenId;
  }

  // The function to get marketplaceStatus array of all NFTs
  function getMarketplaceItems() public view returns (uint256 [] memory) {
    return marketplaceStatusArray;
  }
}