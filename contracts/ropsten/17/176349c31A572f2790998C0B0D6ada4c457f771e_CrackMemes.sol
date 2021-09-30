// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ERC-721 Smart Contract
 */

contract CrackMemes is ERC721, ERC721Burnable, Ownable {
    using SafeMath for uint256;

    string public CRACKMEMES_PROVENANCE = "";

    constructor() ERC721("CrackMemes", "CRACK") {}

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        msg.sender.transfer(balance);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _setBaseURI(baseURI);
    }

    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        CRACKMEMES_PROVENANCE = provenanceHash;
    }

    function mintCrackMemes(uint256 numberOfTokens) public onlyOwner {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            uint256 mintIndex = totalSupply();
            _safeMint(msg.sender, mintIndex);
        }
    }
}