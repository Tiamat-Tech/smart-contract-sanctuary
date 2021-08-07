//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import 'hardhat/console.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTDropBot is ERC721Enumerable, Ownable {
  constructor()
    ERC721(
      'NFTDropBot',
      'NFTDB'
    )
  {}

  function mint(uint256 mintCount) public payable {
    require(msg.value >= 0.05 ether * mintCount, 'Not Enough ETH');

    uint256 totalSupply = totalSupply();

    for (uint256 i = 0; i < mintCount; i++) {
      _safeMint(msg.sender, totalSupply + i);
    }
  }
}