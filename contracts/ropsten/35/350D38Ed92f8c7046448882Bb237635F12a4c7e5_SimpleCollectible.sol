// SPDX-License-Identifier: MIT

pragma solidity  0.6.6;

import "ERC721.sol";

contract SimpleCollectible is ERC721 {

    uint256 tokenCounter;

    constructor () public ERC721("Dogie", "DOG") {
        tokenCounter = 0;
    }

    function createCollectible(string memory tokenURI) public returns (uint256) {
        uint256 newTokenId = tokenCounter;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        tokenCounter = tokenCounter + 1;
        return newTokenId;
    }
}