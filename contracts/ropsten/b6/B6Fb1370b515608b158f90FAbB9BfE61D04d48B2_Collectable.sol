// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "Counters.sol";
import "ERC721URIStorage.sol";

contract Collectable is ERC721URIStorage {
  using Counters for Counters.Counter;
  uint256 public tokenCounter;
  Counters.Counter private _tokenIds;

  constructor () public ERC721("Album", "NextUp") { 
    tokenCounter = 0;
  }

  function createCollectable(string memory tokenURI) public returns(uint256) {
    
    _tokenIds.increment();
    uint256 newTokenId = _tokenIds.current();

    _safeMint(msg.sender, newTokenId);
    _setTokenURI(newTokenId, tokenURI);
    tokenCounter = tokenCounter + 1;
    return newTokenId;
  }

}