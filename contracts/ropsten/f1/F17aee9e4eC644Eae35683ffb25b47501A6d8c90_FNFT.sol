// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";

contract FNFT is ERC721, Ownable {
    uint256 public tokenCounter;
    string public lowImageURI;
    string public highImageURI;
    mapping(uint256 => int) public tokenIdToHighValues;
    event CreatedFeedsNFT(uint256 indexed tokenId);

    constructor(
    ) ERC721("NFT", "NFT")
        public
    {
        tokenCounter = 0;
    }

    function addLowSVG(string memory _svgLowURI) public onlyOwner {
        lowImageURI = _svgLowURI;
    }
    function addHighSVG(string memory _svgHighURI) public onlyOwner {
        highImageURI = _svgHighURI;
    }

    function create() public {
        emit CreatedFeedsNFT(tokenCounter);
        _safeMint(msg.sender, tokenCounter);
        tokenCounter = tokenCounter + 1;
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
                                "Fouera NFT", // You can add whatever name here
                                '", "description":"Fouera NFT", "attributes":"", "image":"',imageURI,'"}'
                            )
                        )
                    )
                )
            );
    }
}