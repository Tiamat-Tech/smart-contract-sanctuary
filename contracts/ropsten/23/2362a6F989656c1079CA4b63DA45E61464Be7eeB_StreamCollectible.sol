// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "ERC721.sol";

contract StreamCollectible is ERC721 {
    uint256 public tokenCounter;

    mapping(uint256 => address) public requestIdToSender;

    constructor() public ERC721("Stream Token", "STT") {
        tokenCounter = 0;
    }

    function createCollectible() public returns (bytes32) {
        uint256 newTokenId = tokenCounter;
        requestIdToSender[newTokenId] = msg.sender;
        address owner = msg.sender;
        _safeMint(owner, newTokenId);
        tokenCounter = tokenCounter + 1;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        // pug, shiba inu, st bernard
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not owner no approved"
        );
        _setTokenURI(tokenId, _tokenURI);
    }
}