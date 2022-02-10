// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract OMGNFT is ERC721URIStorage {
    uint256 public tokenCounter;
    event CreatedOMGNFT(uint256 indexed tokenId, string tokenURI);
    constructor() ERC721 ("OMG NFT", "omgNFT") {
        tokenCounter = 0;
    }

    function create() public {
        _safeMint(msg.sender, tokenCounter);
        string memory tokenURI = "https://asia-northeast1-sekai420.cloudfunctions.net/nft-metadata";
        _setTokenURI(tokenCounter, tokenURI);
        emit CreatedOMGNFT(tokenCounter, tokenURI);
        tokenCounter = tokenCounter + 1;
    }
}