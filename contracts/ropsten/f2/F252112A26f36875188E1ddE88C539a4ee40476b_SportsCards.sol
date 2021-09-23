// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SportsCards is ERC721, ERC721URIStorage, Ownable {
    constructor() ERC721("SportsCards", "CARD") {}

    function mint(address recipient, uint256 tokenId, string memory tokenURIKey)
        public
        payable
        returns (uint256)
    {

        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, tokenURIKey);

        return tokenId;
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
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