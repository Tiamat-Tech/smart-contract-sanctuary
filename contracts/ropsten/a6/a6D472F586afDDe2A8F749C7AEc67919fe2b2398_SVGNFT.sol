// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "base64-sol/base64.sol";

contract SVGNFT is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    uint256 public tokenCounter;
    event CreatedSVGNFT(uint256 indexed tokenId, string tokenURI);

    //uint256 public totalGnomes;
    // uint256 public loopTo;
    // mapping(uint256 => string) public gnomesr;
    string[] public gnomesrr;

    // string[] public gn;

    constructor() ERC721("RandomLines", "RANDNFT") {
        tokenCounter = uint256(0);
        // totalGnomes = uint256(0);
        // loopTo = uint256(100);
    }

    function addGnome(string[] memory gnome) public {
        for (uint256 index = 0; index < gnome.length; index++) {
            gnomesrr.push(
                Base64.encode(bytes(string(abi.encodePacked(gnome[index]))))
            );
        }
        // totalGnomes = totalGnomes.add(uint256(100));
        // loopTo = loopTo.add(totalGnomes);
    }

    function create(string memory svg) public {
        _safeMint(msg.sender, tokenCounter);
        string memory imageURI = svgToImageURI(svg);
        string memory tokenURI = formatTokenURI(imageURI);
        _setTokenURI(tokenCounter, tokenURI);
        emit CreatedSVGNFT(tokenCounter, tokenURI);
        tokenCounter = tokenCounter + 1;
    }

    function svgToImageURI(string memory svg)
        public
        pure
        returns (string memory)
    {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(
            bytes(string(abi.encodePacked(svg)))
        );
        string memory imageURI = string(
            abi.encodePacked(baseURL, svgBase64Encoded)
        );
        return imageURI;
    }

    function formatTokenURI(string memory imageURI)
        public
        pure
        returns (string memory)
    {
        string memory baseURL = "data:application/json;base64,";
        return
            string(
                abi.encodePacked(
                    baseURL,
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name": "RAND"',
                                '"description": "RandomSVGNFT"',
                                '"attributes":""',
                                '"image": "',
                                imageURI,
                                '" }'
                            )
                        )
                    )
                )
            );
    }
}