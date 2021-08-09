// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC721BMPStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFT is ERC721BMPStorage, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address contractAddress;
    address owner;
    uint maxTokens;

    constructor() ERC721("Portrait Token", "PRT") {
        owner = payable(msg.sender);
        maxTokens = 10000;
    }

    function createToken(string memory tokenURI, bytes memory tokenBMP) public payable nonReentrant returns (uint) {
        // check payment ammount is correct
        require(msg.value == getMintingPrice(), "Price must be equal to current getMintingPrice");
        // do not mint more tokens if market cap is reached
        require(_tokenIds.current() < maxTokens, "Total supply limit of tokens has been reached");
        // check BMP data is correct length
        require(tokenBMP.length == 9216, "Bytes data for token bitmap is not correct");
        // check minting is being done by the contract owner
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI, tokenBMP);
        payable(owner).transfer(msg.value);
        return newItemId;
    }

    function ownerCreateToken(string memory tokenURI, bytes memory tokenBMP) public returns (uint) {
        // only owner can create tokens for free
        require(msg.sender == owner, "Function can only be called by contract owner");
        // do not mint more tokens if market cap is reached
        require(_tokenIds.current() < maxTokens, "Total supply limit of tokens has been reached");
        // check BMP data is correct length
        require(tokenBMP.length == 9216, "Bytes data for token bitmap is not correct");
        // check minting is being done by the contract owner
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI, tokenBMP);
        return newItemId;
    }


    // returns cost of minting a token
    function getMintingPrice() public view returns (uint256) {
        return _tokenIds.current() * (0.01 ether);
    }

}