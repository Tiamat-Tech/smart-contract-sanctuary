// https://ethereum.org/en/developers/tutorials/how-to-write-and-deploy-an-nft/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract BitBirds is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // events
    event printNewItemId(uint256 _newItemId);

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mintNFT(address recipient, string memory tokenURI) public onlyOwner returns (uint256) {
      _tokenIds.increment();

      uint256 newItemId = _tokenIds.current();
      _mint(recipient, newItemId);
      _setTokenURI(newItemId, tokenURI);

      emit printNewItemId(newItemId);

      return newItemId;
    }
}