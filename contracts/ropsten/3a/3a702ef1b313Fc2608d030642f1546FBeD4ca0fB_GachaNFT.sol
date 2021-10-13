// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";

contract GachaNFT is ERC721URIStorage {
    uint256 public _tokenCounter;

    event CreatedSVGNFT(uint256 indexed tokenId, string tokenURI);
    
    constructor() ERC721 ("GachaNFT", "Gacha"){
        _tokenCounter = 0;
    }

    function create(string memory svg) public {
        string memory tokenURI = formatTokenURI(svgToImageURI(svg));

        _safeMint(msg.sender, _tokenCounter);
        _setTokenURI(_tokenCounter, tokenURI);
        
        emit CreatedSVGNFT(_tokenCounter, tokenURI);
        
        _tokenCounter += 1;
    }

    function svgToImageURI(string memory svg) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(
                    bytes(
                        string(
                            abi.encodePacked(
                                svg
                            )
                        )
                    )
                )
            )
        );
    }

    function formatTokenURI(string memory imageUri) public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"Gacha NFT", "description":"Gacha NFT Loot Packs", "attributes": [], "image": "',
                            imageUri,
                            '"}'
                        )
                    )
                )
            )
        );
    }
}