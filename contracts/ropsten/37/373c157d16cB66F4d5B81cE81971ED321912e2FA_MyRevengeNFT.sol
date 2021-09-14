// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Love.sol";

contract MyRevengeNFT is ERC721Enumerable, ReentrancyGuard {
    
    address public LoveToken = 0x2F7209Cd0d31A32383BE4A909e2F32094C62e470;
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;

    constructor() ERC721("MyRevengeNFT", "REVENGENFT") {}

    function mintNFT() public payable {
        require(totalSupply() < 10000); //Max Supply 10,000 NFTs
        require(Love(LoveToken).balanceOf(msg.sender) >= 10e18, "Need at least 10 LOVE token to mint!"); //Need at least 10 LOVE to mint
        Love(LoveToken).transferFrom(msg.sender, deadAddress, 10e18); //Burns LOVE tokens. Oh no!!
        uint256 tokenID = totalSupply() + 1; // Increment the supply
        _mint(msg.sender, tokenID); // Mint the NFT to the poor sod.

    }
    function tokenURI() public pure returns (string memory) {
    string memory URI = "https://imgur.com/iG93Nbr.jpg"; 
    return URI;
    }
}