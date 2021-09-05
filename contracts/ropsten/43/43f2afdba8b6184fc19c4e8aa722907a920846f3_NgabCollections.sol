// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NgabCollections is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private mintedCount;

    uint32 public constant MAX_SUPPLY = 1000;
    uint256 public constant TOKEN_PRICE = 0.01 ether;
    uint32 public constant MAX_PER_MINT = 5;

    // baseURI
    string private _uri;

    constructor() ERC721("Ngab", "NGAB") {}

    // @param uri The base uri for the metadata store
    // @dev Allows to set the baseURI dynamically
    function setBaseURI(string memory uri) external onlyOwner {
        _uri = uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return _uri;
    }

    function publicSale(uint256 count) public payable nonReentrant {
        // use msg.value to check the price
        uint256 minted = totalSupply();
        require(count <= MAX_PER_MINT, "kebanyakan gan.");
        require(minted < MAX_SUPPLY, "All ngab tokens have been minted.");
        require(
            (minted + count) <= MAX_SUPPLY,
            "Purchase exceeds total supply."
        );
        require(count > 0, "You have to mint more than 0 tokens.");

        for (uint256 i = 0; i < count; i++) {
            _safeMint(msg.sender, totalSupply());
        }
    }
}