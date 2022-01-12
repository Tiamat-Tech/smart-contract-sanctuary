//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _tokenIds;

    uint256 public maxTokenSupply = 5000;

    uint256 public constant MAX_MINTS_PER_TXN = 5;

    uint256 public mintPrice = 0.005 ether;

    string public baseTokenURI;

    constructor(string memory baseURI) public ERC721("Nameless Nuggets", "NUG") {
        setBaseURI(baseURI);
    }

    function _baseURI() internal 
                        view 
                        virtual 
                        override 
                        returns (string memory) {
        return baseTokenURI;
    }
        
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    } 

    function mintNFT(uint256 numberOfTokens, bool free) public payable {
        uint totalMinted = _tokenIds.current();

        require(totalMinted.add(numberOfTokens) <= maxTokenSupply, "Not enough NFTs to Mint!");
        
        require(numberOfTokens > 0 && numberOfTokens <= MAX_MINTS_PER_TXN, "Can only mint 1 to 5 NFTs per transaction.");

        require(balanceOf(msg.sender) + numberOfTokens <= 10, "Each wallet can only hold 10 NFTs!");

        if(!free) {
            require(msg.value >= mintPrice.mul(numberOfTokens), "Not enough ether to purchase NFTs.");
        }

        for (uint i = 0; i < numberOfTokens; i++) {
            _mintSingleNFT();
        }
    }

    function _mintSingleNFT() private {
        uint newTokenID = _tokenIds.current();
        _safeMint(msg.sender, newTokenID);
        _tokenIds.increment();
    }

    function tokensOfOwner(address _owner) external view returns (uint[] memory) {     
        uint tokenCount = balanceOf(_owner);
        uint[] memory tokensId = new uint256[](tokenCount);     
        for (uint i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw");     
        (bool success, ) = (msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}