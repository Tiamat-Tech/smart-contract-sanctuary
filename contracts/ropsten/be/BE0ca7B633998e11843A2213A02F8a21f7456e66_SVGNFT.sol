//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "base64-sol/base64.sol";
import "hardhat/console.sol";

contract SVGNFT is ERC721URIStorage, Ownable {
    uint256 public tokenCounter = 1;
    uint256 public tbs = 1;
    event CreateSvgNFT(uint256 indexed tokenId, string tokenURI);

    constructor() ERC721("SVG NFT", "svgNFT"){
    }

    function createSVG(string memory svg) public {
        _safeMint(msg.sender, tokenCounter);
         string memory imageURI = svgToImageURI(svg);
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(tokenCounter, tokenURI);
        emit CreateSvgNFT(tokenCounter, tokenURI);
        tokenCounter += 1;
    }

    function svgToImageURI(string memory svg) public pure returns (string memory) {
        // <svg xmlns="http://www.w3.org/2000/svg" version="1.1">
        // <circle cx="100" cy="50" r="40" stroke="black" stroke-width="2" fill="red" />
        // </svg>
        string memory baseURL = "data:image/svg+xml;base64,";
        // data:image/svg+xml;base64, <base64 encode>
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        // PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZlcnNpb249IjEuMSI+CiAgPGNpcmNsZSBjeD0iMTAwIiBjeT0iNTAiIHI9IjQwIiBzdHJva2U9ImJsYWNrIgogIHN0cm9rZS13aWR0aD0iMiIgZmlsbD0icmVkIiAvPgo8L3N2Zz4=
        string memory imageURI = string(abi.encodePacked(baseURL, svgBase64Encoded));
        // data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZlcnNpb249IjEuMSI+CiAgPGNpcmNsZSBjeD0iMTAwIiBjeT0iNTAiIHI9IjQwIiBzdHJva2U9ImJsYWNrIgogIHN0cm9rZS13aWR0aD0iMiIgZmlsbD0icmVkIiAvPgo8L3N2Zz4=
        return imageURI;
    }

    function formatTokenURI(string memory imageURI) public pure returns(string memory) {
        string memory baseURL = "data:application/json;base64,";

        return string(abi.encodePacked(
            baseURL,
            Base64.encode(
                bytes(abi.encodePacked(
                    '{"name": "SVG NFT",',
                    '"description": "An NFT based on SVG",',
                    '"attributes": "",',
                    '"image": "', imageURI, '"}'
                ))
            )
        ));
    }

}