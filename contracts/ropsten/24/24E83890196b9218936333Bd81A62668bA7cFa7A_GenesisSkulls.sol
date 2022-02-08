// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// @title:     Genesis Skulls
// @artist:    Crhis Vance @ https://chrisvanceart.com/
// @company:   NiftyFusions @ http://niftyfusions.com/
// @dev:       Mr.Wizard

/*
*█─▄▄▄▄█▄─▄▄─█▄─▀█▄─▄█▄─▄▄─█─▄▄▄▄█▄─▄█─▄▄▄▄███─▄▄▄▄█▄─█─▄█▄─██─▄█▄─▄███▄─▄███─▄▄▄▄█
*█─██▄─██─▄█▀██─█▄▀─███─▄█▀█▄▄▄▄─██─██▄▄▄▄─███▄▄▄▄─██─▄▀███─██─███─██▀██─██▀█▄▄▄▄─█
*▀▄▄▄▄▄▀▄▄▄▄▄▀▄▄▄▀▀▄▄▀▄▄▄▄▄▀▄▄▄▄▄▀▄▄▄▀▄▄▄▄▄▀▀▀▄▄▄▄▄▀▄▄▀▄▄▀▀▄▄▄▄▀▀▄▄▄▄▄▀▄▄▄▄▄▀▄▄▄▄▄▀
*/

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GenesisSkulls is ERC721A, Ownable, ReentrancyGuard {
    using Address for address;

    // ===== Variables =====
    string public baseTokenURI;
    uint256 public collectionSize = 25;

    bool public publicMintPaused = true;

    // ===== Constructor =====
    constructor() ERC721A("Genesis Skulls", "GS") {}

    // ===== Reserve mint =====
    function devMint(uint256 amount) external onlyOwner nonReentrant {
        require((totalSupply() + amount) <= collectionSize, "Sold out!");
        _safeMint(msg.sender, amount);
    }

    // ===== Setter =====
    function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner nonReentrant {
        baseTokenURI = _baseTokenURI;
    }

    // ===== Withdraw ETH =====
    function withdraw(address to, uint256 amount) external onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Exceed balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Failed to send ether");
    }

    function withdrawAll() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Failed to send ether");
    }

    // ===== View =====
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI, Strings.toString(tokenId), ".json"));
    }
}