// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import  "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract CryptoPunks is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() public ERC721("CryptoPunksLow#2", "CP") {} //ВВЕДИ НАЗВАНИЕ И СИМВОЛ ТОКЕНА


    function createNFT(address receiver, string memory tokenURI) public onlyOwner returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(receiver, newItemId);
        _setTokenURI(newItemId, tokenURI);

      
        return newItemId;
    }
}