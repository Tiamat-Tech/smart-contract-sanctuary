// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BigBlockOfCheese is ERC721Enumerable, ReentrancyGuard, Ownable {

    uint16 private constant MAX_SUPPLY = 10000;
    uint16 private constant OWNER_SUPPLY = 500;

    constructor() ERC721("Big Block of Cheese", "BBOC") Ownable() {}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function claim(uint256 tokenId) public nonReentrant {
        require(tokenId > 0 && tokenId < (MAX_SUPPLY - OWNER_SUPPLY), "Token ID invalid");
        _safeMint(_msgSender(), tokenId);
    }
}