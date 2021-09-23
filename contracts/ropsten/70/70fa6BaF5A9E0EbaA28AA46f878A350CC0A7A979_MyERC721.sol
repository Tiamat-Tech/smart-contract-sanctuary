// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "@openzeppelin/contracts/utils/Counters.sol";

contract MyERC721 is ERC721URIStorage{

    using Counters for Counters.Counter;
    Counters.Counter private tokenId;
    constructor() ERC721('NayaToken','NYT'){}

    function mintYourNFT(address tokenAddress, string memory tokenURI) public  returns (uint){
        tokenId.increment();
        uint newTokenId = tokenId.current();
        _mint(tokenAddress, newTokenId);
         _setTokenURI(newTokenId,tokenURI);
        return newTokenId;

    }
}