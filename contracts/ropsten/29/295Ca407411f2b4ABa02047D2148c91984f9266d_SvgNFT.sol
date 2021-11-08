pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "base64-sol/base64.sol";

contract SvgNFT is ERC721URIStorage {
    uint256 public tokenCount;
    event CreatedSvgNFT(uint256 indexed tokenId, string tokenURI);

    constructor() ERC721 ("SvgNFT", "svgNFT") {
        tokenCount = 0;
    }

    function mint(string memory _svg) public {
        _safeMint(msg.sender, tokenCount);
        string memory imageURI = svgToImageURI(_svg);
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(tokenCount, tokenURI);
        emit CreatedSvgNFT(tokenCount, tokenURI);
        tokenCount = tokenCount + 1;
    }

    function svgToImageURI(string memory _svg) public pure returns (string memory) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(_svg))));

        string memory imageURI = string(abi.encodePacked(baseURL, svgBase64Encoded));

        return imageURI;
    }

    function formatTokenURI(string memory _imageURI) public pure returns (string memory) {

        string memory baseURL = "data:application/json;base64,";

        // Base URL concatenated with token URI
        return string(abi.encodePacked(
            baseURL,
            Base64.encode(
                bytes(abi.encodePacked(
                    '{"name": "SvgNFT", "description": "An NFT based on SVG", "image": "', _imageURI, '"}'
                )
            ))
        ));    
    }
}