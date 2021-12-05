/*

(it's not loot)
    
*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Not Loot
contract NotLoot is ERC721, Ownable {
    constructor() ERC721("Loot Crystals", "CRYSTAL") Ownable() {}

    function mint(uint256 tokenId) external {
        _mint(_msgSender(), tokenId);
    }
}