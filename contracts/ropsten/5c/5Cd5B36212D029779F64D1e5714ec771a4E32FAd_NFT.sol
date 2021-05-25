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


    function issueToken(address holder, string memory uri) external  onlyOwner {
        //uris<50
        //gasused, 8 milionov gaza
        //require(uri); //check if not empty
        safeMint(holder, uri);
        _setTokenURI(getIdTracker(), uri);
    }

    function safeMint(address holder, string memory _tokenURI) internal  {
        _tokenIdTracker.increment();
        _safeMint(holder, getIdTracker());

    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _setBaseURI(baseURI);
    }

    function getIdTracker() public view returns(uint256) {
        return _tokenIdTracker.current();
    }

}