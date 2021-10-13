// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "base64-sol/base64.sol";

contract SVGNFT is ERC721URIStorage{
    uint256 public tokenCounter;
    event CreatedSVGNTF(uint256 indexed tokenID, string tokenURI);

   constructor() ERC721("DHP SVG NFT01","dhpsvgnft01"){
        tokenCounter = 0;
    }
    function create(string memory _svg) public{
        _safeMint(msg.sender, tokenCounter);
        string memory imageURI = svgToImageURI(_svg);
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(tokenCounter, tokenURI);
        emit CreatedSVGNTF(tokenCounter, tokenURI);
        tokenCounter = tokenCounter + 1;    
    }
    function svgToImageURI(string memory _svg) public pure returns(string memory){
         string memory baseURL = "data:image/svg+xml;base64,";
         string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(_svg))));
        string memory imageURI = string(abi.encodePacked(baseURL, svgBase64Encoded));
        return imageURI;
    }
    function formatTokenURI(string memory _imageURI)public pure returns(string memory){
        return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"SVG NFT", ', // You can add whatever name here
                                '"description":"An NFT based on SVG!", ', 
                                '"attributes":"", ',
                                '"image":"',_imageURI,'"}'
                            )
                        )
                    )
                )
            );
    }
}