// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import 'base64-sol/base64.sol';
import "hardhat/console.sol";

contract Brainfck is ERC721 {
    string private baseURL = 'ipfs:QmU3N7kCoEsGJcTiAfhtp1x7Zz1YgESJY7o41hUTvFLVPq/';

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {
        for (uint i = 0; i < 100; i++) {
            _mint(msg.sender, i);
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        string memory json = Base64.encode(bytes(string(abi.encodePacked(
            '{"name": "', 
            _tokenNames[tokenId], 
            '", "image": "', 
            baseURL, 
            Strings.toString(tokenId), 
            '.png', '"}'
        ))));
        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    function imageURI(uint256 tokenId) public view virtual returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        return string(abi.encodePacked(
            baseURL, 
            Strings.toString(tokenId),
            '.png'
        ));
    }

    string[100] private _tokenNames = [
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor",
        "Lorem ipsum dolor"
    ];
}