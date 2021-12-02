//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './IEgg.sol';
import './IAnts.sol';

contract Ants is ERC721Enumerable, IAnts, Ownable {
  constructor(address cryptoAnts) ERC721('Crypto Ants', 'ANTS') {
    transferOwnership(cryptoAnts);
  }

  function mint(address to, uint256 tokenId) external override onlyOwner {
    _safeMint(to, tokenId);
  }

  function burn(uint256 tokenId) external override onlyOwner {
    _burn(tokenId);
  }
}