// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Ports is ERC721URIStorage {
    address Owner;

    mapping(uint256 => string[]) _metadata; // mapping where the key is the tokenId and the value is metadataArray

    constructor () ERC721("Ports", "PORTNET") {
        Owner = msg.sender;
    }

    function mint(address _to, uint256 tokenId, string memory _tokenMetadata) public {
        _mint(_to,tokenId);
        _metadata[tokenId].push(_tokenMetadata);
    }

    function setTokenMetadata(uint256 tokenId, string memory _tokenMetadata) public {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _metadata[tokenId].push(_tokenMetadata);
    }

    function getMetadata(uint256 tokenId, uint index) public view returns (string memory){
        return _metadata[tokenId][index];
    }
}