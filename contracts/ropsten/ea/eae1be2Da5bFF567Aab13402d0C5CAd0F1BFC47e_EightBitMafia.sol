// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EightBitMafia is ERC721Enumerable, Ownable {
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

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function initialMint() public onlyOwner {
        _safeMint(msg.sender, 1);
        _safeMint(msg.sender, 2);
        _safeMint(msg.sender, 3);
        _safeMint(msg.sender, 4);
        _safeMint(msg.sender, 5);
        _safeMint(msg.sender, 6);
        _safeMint(msg.sender, 7);
        _safeMint(msg.sender, 8);
        _safeMint(msg.sender, 9);
        _safeMint(msg.sender, 10);
        _safeMint(msg.sender, 11);
        _safeMint(msg.sender, 12);
        _safeMint(msg.sender, 13);
        _safeMint(msg.sender, 14);
        _safeMint(msg.sender, 15);
        _safeMint(msg.sender, 16);
        _safeMint(msg.sender, 17);
        _safeMint(msg.sender, 18);
        _safeMint(msg.sender, 19);
        _safeMint(msg.sender, 20);
    }

    function secondMint() public onlyOwner {
        _safeMint(msg.sender, 21);
        _safeMint(msg.sender, 22);
        _safeMint(msg.sender, 23);
        _safeMint(msg.sender, 24);
        _safeMint(msg.sender, 25);
        _safeMint(msg.sender, 26);
        _safeMint(msg.sender, 27);
        _safeMint(msg.sender, 28);
        _safeMint(msg.sender, 29);
        _safeMint(msg.sender, 30);
        _safeMint(msg.sender, 31);
        _safeMint(msg.sender, 32);
        _safeMint(msg.sender, 33);
        _safeMint(msg.sender, 34);
        _safeMint(msg.sender, 35);
    }

    function thirdMint() public onlyOwner {
        _safeMint(msg.sender, 36);
        _safeMint(msg.sender, 37);
        _safeMint(msg.sender, 38);
        _safeMint(msg.sender, 39);
        _safeMint(msg.sender, 40);
        _safeMint(msg.sender, 41);
        _safeMint(msg.sender, 42);
        _safeMint(msg.sender, 43);
        _safeMint(msg.sender, 44);
        _safeMint(msg.sender, 45);
        _safeMint(msg.sender, 46);
        _safeMint(msg.sender, 47);
        _safeMint(msg.sender, 48);
        _safeMint(msg.sender, 49);
        _safeMint(msg.sender, 50);
    }
}