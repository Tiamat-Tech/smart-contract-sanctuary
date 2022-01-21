// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

//FOR TESTING PURPOSES ONLY
contract NFTHero is ERC721Enumerable, Ownable {
    constructor() ERC721("DP", "DEP") Ownable() {}

    function mint() public payable {
        _safeMint(msg.sender, totalSupply() + 1);
    }
}