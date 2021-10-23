// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";

// The most basic NFT contract ever. This must be so easy!
contract TheEighthWord is ERC721, Ownable {
    constructor() ERC721("TheEighthWord", "SEED8 ") {}

    // This next puzzle is inter-planetary
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmcvEPZck82MrVWtuoRSADkFGE39aFuHaa52oX1ibskj55/metadata.json";
    }

    function safeMint(uint256 tokenId) public {
        _safeMint(msg.sender, tokenId);
    }
}