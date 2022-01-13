//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    uint256 private price;

    constructor() public ERC721("MyNFT", "NFT") {
        price = 1 ether;
    }

    function setPrice(uint256 _price) public {
        price = _price;
    }

    function mintFreeNFT(address recipient, string memory tokenURI, uint256 _numTokens)
        public
        returns (uint256)
    {
        for (uint256 i; i < _numTokens; i++) {
            tokenIds.increment();

            uint256 newItemId = tokenIds.current();
            _mint(recipient, newItemId);
            _setTokenURI(newItemId, tokenURI);

        }
    }

    function mintPaidNFT(address recipient, string memory tokenURI, uint256 _numTokens)
        public payable
        returns (uint256)
    {
        require(msg.value >= (price * _numTokens), "Not enough ETH sent; check price!"); 

        for (uint256 i; i < _numTokens; i++) {
            tokenIds.increment();

            uint256 newItemId = tokenIds.current();
            _mint(recipient, newItemId);
            _setTokenURI(newItemId, tokenURI);
   
        }
    }
}