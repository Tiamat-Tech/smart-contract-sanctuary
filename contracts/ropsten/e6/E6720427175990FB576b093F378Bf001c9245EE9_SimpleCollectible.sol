// SPDX-License-Identifier: MIT
// Create a simple collectible smart contract that only the owner of the contract can mint new tokens.
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

contract SimpleCollectible is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor(string memory _tokenName, string memory _tokenSymbol)
    ERC721(_tokenName, _tokenSymbol)
  {}

  /**
        Assign a new token id to the owner of the token (Mint). 
        The token id is a number that is unique to the token.
        The token URI is the external path to the data the token represents.
    **/
  function mintItem(address owner, string memory tokenURI)
    public
    returns (uint256)
  {
    _tokenIds.increment();

    uint256 newItemId = _tokenIds.current();
    _safeMint(owner, newItemId); // Creates an unique nft by updating the owners mapping to tokenIds
    _setTokenURI(newItemId, tokenURI);

    return newItemId;
  }
}