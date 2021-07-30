//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NftFactory is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() ERC721("tasteful-tenders-NFT", "TTS") {}

  function mintNft(address _owner, string memory _tokenURI) public returns (uint256) {
    _tokenIds.increment();

    uint256 newNftId = _tokenIds.current();
    _mint(_owner, newNftId);
    _setTokenURI(newNftId, _tokenURI);

    return newNftId;
  }
}