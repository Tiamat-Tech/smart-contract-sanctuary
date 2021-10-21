// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFT is ERC721URIStorage {
    event NftBought(address _seller, address _buyer, uint256 _price);

    mapping (uint256 => uint256) public tokenIdToPrice;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("TokenMind", "TMFT") {
    }

    function createToken(string memory tokenURI) public returns (uint) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        tokenIdToPrice[newItemId] = 0.1 ether;
        return newItemId;
    }

    function buyRandomToken() external payable {
        uint tokenId = random() + 1;
        uint256 price = tokenIdToPrice[tokenId];
        require(price > 0, 'This token is not for sale');
        require(msg.value == price, 'Incorrect value');

        address seller = ownerOf(tokenId);
        _transfer(seller, msg.sender, tokenId);
        tokenIdToPrice[tokenId] = 0; // not for sale anymore
        payable(seller).transfer(msg.value); // send the ETH to the seller

        emit NftBought(seller, msg.sender, msg.value);
    }

    function random() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp))) % _tokenIds.current();
    }
}