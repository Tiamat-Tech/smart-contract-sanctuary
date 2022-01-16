pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";

contract SimpleCollectible is ERC721 {
    uint256 public tokenCounter;
    constructor() public ERC721("Dogie","DOG"){
        tokenCounter = 0;
    }

    function createCollectible(string memory tokenURI) public returns (uint256) {
        uint256 newItemId = tokenCounter;
        console.log(tokenCounter);
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        tokenCounter = tokenCounter + 1;    
        return newItemId;

    }

    function getMintedNFT() public view returns (uint256) {
        return tokenCounter;

    }
}