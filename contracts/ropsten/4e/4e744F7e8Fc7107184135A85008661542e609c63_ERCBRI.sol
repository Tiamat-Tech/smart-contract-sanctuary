// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract ERCBRI is ERC721URIStorage {
    address Owner;

    mapping(uint256 => string) _creatorDid; //mapping where the key is the user and the value is the did
    mapping(uint256 => string) _didNFT; //mapping where the key is the tokenId and the value is the didNFT

    constructor () ERC721("Scents", "SCENT") {
        Owner = msg.sender;
    }

    function mint(address _to, uint256 tokenId, string memory creatorDid, string memory didNFT, string memory tokenURI) public {
        _creatorDid[tokenId] = creatorDid;
        _didNFT[tokenId] = didNFT;
        _mint(_to,tokenId);
        _setTokenURI(tokenId, tokenURI);
    }

    function getDid(uint256 tokenId) public view returns (string memory){
        return _creatorDid[tokenId];
    }

    function getDidNFT(uint256 tokenId) public view returns (string memory){
        return _didNFT[tokenId];
    }
}