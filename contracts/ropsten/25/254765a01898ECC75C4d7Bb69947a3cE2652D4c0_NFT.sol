//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract NFT is ERC721URIStorage, Ownable {

    // Base URI
    string private baseTokenURI;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function _mintFor(address owner, uint256 tokenId) external onlyOwner {
        _safeMint(owner, tokenId);
    }

    function _setBaseURI(string memory baseURI) external onlyOwner() {
        baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
}