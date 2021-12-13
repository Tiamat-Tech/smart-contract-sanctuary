//SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

/*
    Ant NFT Token
 */
contract Ant is ERC721, ERC721Burnable, Ownable {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  constructor(address _exchange) ERC721('Crypto Ants', 'ANTS') {
    transferOwnership(_exchange);
  }

  /*
    Mints a new Ant with incremental id and approves the exchange.
   */
  function safeMint(address to) public onlyOwner returns (uint256) {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    _approve(owner(), tokenId);
    return tokenId;
  }
}