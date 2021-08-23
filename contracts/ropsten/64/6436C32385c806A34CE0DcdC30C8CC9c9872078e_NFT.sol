// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract NFT is ERC721, ERC721URIStorage, ERC721Burnable {
    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://";
    }

    function safeMint(
        address to,
        uint256 tokenId,
        string memory _tokenURI
    ) public {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    // The following functions are overrides required by Solidity.

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
}