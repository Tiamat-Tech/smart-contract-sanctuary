// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";

contract Afternoon is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    
    uint256 public constant maxTokens = 10000;
    uint256 public constant maxPerTx = 10;
    uint256 public tokenPrice = 0.069 ether;
    uint256 private _reserved = 10;

    constructor() ERC721("Afternoon", "AFT") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://RENAME_ME_WEBSITE.com/";
    }
    
    function createAfternoon(uint256 num) public payable {
        uint256 supply = totalSupply();
        require(msg.value >= tokenPrice * num, "Not enough ether sent");
        require(num <= maxPerTx, "You can create a maximum of 10 Afternoon");
        require(supply + num < maxTokens - _reserved, "Would exceed maximum Afternoon");
        require(msg.sender == tx.origin, "No contracts!");
        
        for(uint256 i; i < num; i++) {
            _safeMint( msg.sender, supply + i );
        }
    }
    
    function withdraw() public onlyOwner {
        require(address(this).balance > 0, "Balance is 0");
        payable(owner()).transfer(address(this).balance);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}