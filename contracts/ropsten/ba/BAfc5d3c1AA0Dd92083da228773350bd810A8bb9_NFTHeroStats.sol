// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "hardhat/console.sol";

//FOR TESTING PURPOSES ONLY
contract NFTHeroStats is ERC721Enumerable, Ownable {
    constructor() ERC721("NFTHeroStats", "NHS") Ownable() {}

    struct Character {
        uint256 strength;
        uint256 agility;
        uint256 intelligence;
        uint256 vitality;
        uint256 luck;
    }

    mapping(uint256 => Character) public idToCharacters;

    function mint() public payable {
        uint256 nftId = totalSupply() + 1;

        idToCharacters[nftId] = Character(nftId, nftId, nftId, nftId, nftId);

        _safeMint(msg.sender, nftId);
    }
}