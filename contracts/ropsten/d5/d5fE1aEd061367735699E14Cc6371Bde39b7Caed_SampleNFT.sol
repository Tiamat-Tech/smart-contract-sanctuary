// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./../node_modules/@openzeppelin/contracts/utils/Counters.sol";
import "./../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SampleNFT is ERC721URIStorage {
    using Counters for Counters.Counter;

    constructor() public ERC721("SampleNFT", "SAMPLONE") {
        _tokenIds.increment();
    }

    Counters.Counter private _tokenIds;

    function mintNFT(address recipient, string memory tokenURI) public returns (uint256) {
        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        _tokenIds.increment();
        return newItemId;
    }

    function burn(uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(owner == msg.sender, "Invalid owner");
        _burn(tokenId);
    }
}