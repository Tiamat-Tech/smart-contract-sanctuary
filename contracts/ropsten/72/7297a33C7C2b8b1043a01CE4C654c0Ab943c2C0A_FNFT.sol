// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";

contract FNFT is ERC721, Ownable {
    uint256 public tokenCounter;
    string public lowImageURI;

    mapping(uint256 => int) public tokenIdToHighValues;
    event CreatedFeedsNFT(uint256 indexed tokenId);

    constructor(
    ) ERC721("NFT", "NFT")
        public
    {
        tokenCounter = 0;
    }

    function addLowURI(string memory _svgLowURI) public onlyOwner {
        lowImageURI = _svgLowURI;
    }   

    function addLowSVG(string memory _svgLowRaw) public onlyOwner {
        string memory svgURI = svgToImageURI(_svgLowRaw);
        addLowURI(svgURI);
    }

    function create() public {
        emit CreatedFeedsNFT(tokenCounter);
        _safeMint(msg.sender, tokenCounter);
        tokenCounter = tokenCounter + 1;
    }
    // You could also just upload the raw SVG and have solildity convert it!
    function svgToImageURI(string memory svg) public pure returns (string memory) {
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked(baseURL,svgBase64Encoded));
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory imageURI = lowImageURI;
        return string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                "Chainlink Feeds NFT", // You can add whatever name here
                                '", "description":"An NFT that changes based on the Chainlink Feed", "attributes":"", "image":"',imageURI,'"}'
                            )
                        )
                    )
                )
            );
    }
}