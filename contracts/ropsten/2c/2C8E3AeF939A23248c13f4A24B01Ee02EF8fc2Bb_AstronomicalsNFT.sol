// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract AstronomicalsNFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    
    uint public constant MAX_SUPPLY = 20;
    uint public constant PRICE = 0.01 ether;
    
    string public baseTokenURI;

    constructor(string memory baseURI) ERC721("Astronomicals", "ASTRONOM") {
        setBaseURI(baseURI);
    }
    
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    } 

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function mint() public payable returns(uint256) {
        require(totalSupply() < MAX_SUPPLY, "Max supply reached. No more NFTs can be minted.");
        require(msg.value >= PRICE, "Not enough ether to mint NFT.");

        _tokenIds.increment();
        
        uint tokenId = _tokenIds.current(); 
        _safeMint(msg.sender, tokenId);
        
        return tokenId;
    }

    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");

        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }
    
}