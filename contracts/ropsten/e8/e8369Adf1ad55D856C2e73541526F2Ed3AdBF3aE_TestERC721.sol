// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract TestERC721 is ERC721Enumerable, Ownable {
    constructor() ERC721("Test ERC721", "T721") {}

    string public constant ORIGINAL_PROVENANCE = "ac39af4793119ee46bbff351d8cb6b5f23da60222126add4268e261199a2921b";
    uint256 public constant MAX_SUPPLY = 10000;

    string private _baseTokenURI;

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    function mintTokens(uint256 count) external onlyOwner {
        uint256 currentSupply = totalSupply();
        require(currentSupply + count <= MAX_SUPPLY, "Trying to mint more than max supply");

        for (uint8 i = 0; i < count; i++) {
            _mint(msg.sender, currentSupply + i);
        }
    }
}