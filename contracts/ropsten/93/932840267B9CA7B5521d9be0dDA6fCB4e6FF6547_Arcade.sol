// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract Arcade is ERC721URIStorage, ERC721Enumerable {
    string baseURI;
    constructor() ERC721("Arcade", "ARCADE") {}

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) 
        internal 
        override(ERC721, ERC721URIStorage) 
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _baseURI() 
        internal 
        view 
        override 
        returns (string memory) 
    {
        return baseURI;
    }

    function mint(
        address account,
        uint256 tokenId
    ) external {
        _mint(account, tokenId);
    }
    
    function setTokenURI(
        uint256 tokenId, 
        string memory inputTokenURI
    ) external {
        _setTokenURI(tokenId, inputTokenURI);
    }
    
    function setBaseURI(string memory baseURI_) external {
        baseURI = baseURI_;
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}