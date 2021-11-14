// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EightBitMafia is ERC721 {
    using Strings for uint256;

    string public baseURI;
    string public baseExtension = ".json";
    string public notRevealedUri;

    uint256 public cost = 0.055 ether;
    uint256 public bulkCost = 0.047 ether;
    uint256 public maxSupply = 8888;
    uint256 public initialSupply = 4444;
    uint256 public maxMintAmount = 6;

    bool public supplyReleased = false;
    bool public paused = true;
    bool public revealed = false;
    bool public contractBurned = false;

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}
}