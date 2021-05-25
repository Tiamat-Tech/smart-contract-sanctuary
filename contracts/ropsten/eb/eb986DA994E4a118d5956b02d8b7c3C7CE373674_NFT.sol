// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFT is ERC721, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    constructor(string memory name,string memory symbol)  ERC721(name, symbol) {}

    function baseTokenURI() public view returns (string memory) {
        return "https://gateway.pinata.cloud/ipfs/";
    }


    function issueToken(address holder, string memory uri) public  onlyOwner {
        //uris<50
        //gasused, 8 milionov gaza
        //require(uri); //check if not empty
        safeMint(holder, uri);
    }

    function safeMint(address holder, string memory _tokenURI) internal  {
        _tokenIdTracker.increment();
        _safeMint(holder, getIdTracker());

    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal override{
        _setTokenURI(tokenId, _tokenURI);
        //id =1
        //uri = 'base.com/token/sgsd4tDFH4y6'
        //todo: unique uri - TEST
        //string=>bool
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    function getIdTracker() public view returns(uint256) {
        return _tokenIdTracker.current();
    }

}