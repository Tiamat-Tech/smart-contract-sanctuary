// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BYOPillMock is ERC721, ERC721Enumerable, Ownable {
    constructor() ERC721("BYPMOCK", "BYPMOCK") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://api.byopills.com/token/";
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function ownerMint (address to, uint256 numTokens) public onlyOwner {
        for (uint256 index = 0; index < numTokens; index++) {
            uint256 x = totalSupply();
            safeMint(to, x);
        }
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}