// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./YoloInterfaces.sol";

/**
 * NFT Representing ownership of a property on the Yolo Board.
 */

contract YoloDeed is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    IYoloChips public yieldToken;

    Counters.Counter private _tokenIdCounter;

    constructor(address _yieldToken) ERC721("Yolo Deeds", "DEED") {
        yieldToken = IYoloChips(_yieldToken);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://api.yolodice.xyz/deed/";
    }

    function safeMint(address to) public onlyOwner {
        _safeMint(to, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    // Required for use by other contracts.

    function yieldRate(uint256 tokenId) external pure returns (uint256) {
        // TODO: Right now this returns fixed rates based on token ID for testing.
        uint rarity = tokenId % 4;
        
        if (rarity == 0) {
            return 10;
        }
        if (rarity == 1) {
            return 20;
        }
        if (rarity == 2) {
            return 30;
        }
        return 40;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        // Inform the yield token ownership is changing.
        yieldToken.updateOwnership(from, to);
        super._beforeTokenTransfer(from, to, tokenId);
    }

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}