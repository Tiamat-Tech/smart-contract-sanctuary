// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Test is ERC721Enumerable {
    using Strings for uint256;
    string public baseURI;
    string public contractURI;
    uint256 public price = 0.003 ether;
    uint256 public limit = 2;
    uint256 public time = 163300680;

    constructor(string memory _baseURI, string memory _contractURI) ERC721("Test", "T") {
        baseURI = _baseURI;
        contractURI = _contractURI;
    }

    function getTest(uint256 count) public payable {
        require(count <= limit, "A");
        require(block.timestamp >= time, "B");
        require(msg.value >= price * count, "C");
        for (uint256 x = 1; x <= count; x++) {
            _safeMint(msg.sender, totalSupply() + x);
        }
    }
}