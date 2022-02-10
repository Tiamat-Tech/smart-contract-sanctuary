// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "hardhat/console.sol";

contract XNFT is ERC721URIStorage {
    uint256 public tokenCounter;
    event CreatedOMGNFT(uint256 indexed tokenId, string tokenURI);
    constructor() ERC721 ("X NFT", "xNFT") {
        tokenCounter = 0;
    }

    function create() public {
        _safeMint(msg.sender, tokenCounter);
        string memory tokenURI = "https://asia-northeast1-sekai420.cloudfunctions.net/nft-metadata";
        _setTokenURI(tokenCounter, tokenURI);
        emit CreatedOMGNFT(tokenCounter, tokenURI);
        tokenCounter = tokenCounter + 1;
    }

    function holder() public view returns (address[] memory hodlers) {
        uint256 count = tokenCounter;
        hodlers = new address[](count);
        for (uint i=0; i<count; i++) {
            hodlers[i] = ownerOf(i);
        }
        return hodlers;
    }
}