// Created by:

// 888b     d888 d8b          888                    .d8888b.            .d8888b.  888                                 888          
// 8888b   d8888 Y8P          888                   d88P  "88b          d88P  Y88b 888                                 888          
// 88888b.d88888              888                   Y88b. d88P          Y88b.      888                                 888          
// 888Y88888P888 888 88888b.  888888 .d8888b         "Y8888P"            "Y888b.   88888b.   .d88b.  888  888  .d88b.  888 .d8888b  
// 888 Y888P 888 888 888 "88b 888    88K            .d88P88K.d88P           "Y88b. 888 "88b d88""88b 888  888 d8P  Y8b 888 88K      
// 888  Y8P  888 888 888  888 888    "Y8888b.       888"  Y888P"              "888 888  888 888  888 Y88  88P 88888888 888 "Y8888b. 
// 888   "   888 888 888  888 Y88b.       X88       Y88b .d8888b        Y88b  d88P 888  888 Y88..88P  Y8bd8P  Y8b.     888      X88 
// 888       888 888 888  888  "Y888  88888P'        "Y8888P" Y88b       "Y8888P"  888  888  "Y88P"    Y88P    "Y8888  888  88888P' 

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";


contract CardsRehash is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    

    constructor() ERC721("Mints & Shovels Cards", "MNS") {}
        

    function mintNFT(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {       

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;

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


  // EIP2981 standard royalties return.
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view 
        returns (address receiver, uint256 royaltyAmount)
    {
        return (0xe24974150f6Ae456ca04f9708F88F2c98d9f5F19, (_salePrice * 1000) / 10000);
    }

// EIP2981 standard Interface return. Adds to ERC721 Interface returns.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721)
        returns (bool)
    {
        return (
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId)
        );
    }

// freeze metadata
    event PermanentURI(string _value, uint256 indexed _id); 
    }