//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Peace is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    
    Counters.Counter private _tokenIds;
    mapping(address=>bool) public claimed;
    uint constant public TOKEN_LIMIT = 100e3;
    string public unrevealedURI;
    bool public revealed;

    constructor() ERC721("Peace", "PEACE") { }

    function mintNFT() public payable {
        require(claimed[msg.sender] == false, "already claimed");
        require(_tokenIds.current() <= TOKEN_LIMIT, "limit reached");

        uint256 newItemId = _tokenIds.current();

        claimed[msg.sender] = true; 
        _tokenIds.increment();
        
        _mint(msg.sender, newItemId);
    }

    function retrieveFunds(address payable to) external onlyOwner {
        to.transfer(address(this).balance);
    }

    function setParams(string memory newUnrevealedURI, bool revealCollection) external onlyOwner {
        unrevealedURI = newUnrevealedURI;
        revealed = revealCollection;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if(!revealed){
            return unrevealedURI;
        } else {
            return super.tokenURI(id);
        }
    }
}