//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";


contract AiNFT is Ownable, ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("AiNFT", "NFT") {}
    
    mapping (uint256 => address) internal tokenIdToOwner;
    mapping (uint256 => string) internal tokenIdToAttrName;
    mapping (uint256 => string) private _tokenURIs;


    function _isOwner(address sender, uint256 tokenId) 
    internal view
    returns (bool) {
        return ownerOf(tokenId) == sender;
    }
    
    function getName(uint256 tokenId) external view returns (string memory) {
        return tokenIdToAttrName[tokenId];
    }
    
    function changeName(string memory newName, uint256 tokenId, string memory newTokenURI) external  {
        require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: caller is not owner nor approved"
            );
        tokenIdToAttrName[tokenId] = newName;
        _setTokenURI(tokenId, newTokenURI);
    }
    
    function mintNFT(address recipient, string memory tokenURI, string memory attrName)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);
        tokenIdToAttrName[newItemId] = attrName;

        return newItemId;
    }
}