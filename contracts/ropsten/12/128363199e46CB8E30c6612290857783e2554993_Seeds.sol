// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "base64-sol/base64.sol";

contract Seeds is ERC721URIStorage, Ownable {
    string constant JSON_TOKEN_URI_NAME = "Seeds";
    string constant JSON_TOKEN_URI_DESC = "Seeds Description";

    uint256 public tokenCounter;

    event SeedCreated(uint256 indexed tokenId, string tokenURI);

    constructor() ERC721('Seeds', 'seeds') {
        tokenCounter = 0;
    }

    function create(string memory svg) public {
        _safeMint(msg.sender, tokenCounter);
        _setTokenURI(tokenCounter, toJsonTokenURI(toSvgImageURI(svg)));
        emit SeedCreated(tokenCounter, svg);
        tokenCounter++;
    }

    function toSvgImageURI(string memory svg) private pure returns (string memory) {
        string memory svgEncoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked('data:image/svg+xml;base64,', svgEncoded));
    }

    function toJsonTokenURI(string memory imageURI) private pure returns(string memory) {
        string memory jsonEnecoded = Base64.encode(bytes(string(abi.encodePacked(
            '{',
            '"name":"', JSON_TOKEN_URI_NAME, '",',
            '"description":"', JSON_TOKEN_URI_DESC, '",',
            '"image":"', imageURI, '"',
            '}'
        ))));
        return string(abi.encodePacked('data:application/json;base64,', jsonEnecoded));
    }
}