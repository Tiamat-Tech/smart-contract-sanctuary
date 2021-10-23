// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Eye is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint TOKEN_PRICE = 0.04 ether;
    uint MAX_SUPPLY = 100;

    string private _tokenBaseURI = "";

    constructor() ERC721("Eye", "EYE") {}

    function mint(uint qty) external payable {
        require(totalSupply() < MAX_SUPPLY, "SOLD_OUT");
        require(msg.value >= qty * TOKEN_PRICE, "NOT_ENOUGH_FUNDS");

        for (uint i = 0; i < qty; i++) {
            _safeMint(msg.sender, totalSupply() + 1);
        }
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns(string memory) {
        require(_exists(tokenId), "Trying to query a nonexistent token");

        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString(), ".json"));
    }

    function setBaseURI(string memory _baseURI) public onlyOwner {
        _tokenBaseURI = _baseURI;
    }
}