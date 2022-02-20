// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BaseNFT is ERC721Enumerable, PaymentSplitter {
    using Counters for Counters.Counter;
    
    uint256 private constant MAX_NFTS = 20;
    uint256 private constant PRICE = 0.001 ether;

    Counters.Counter private _tokenIdCounter;

    constructor(address[] memory payees, uint256[] memory shares)
            ERC721("Base NFTs", "BASE")
            PaymentSplitter(payees, shares) {
        // do nothing
    }

    function mint(address to) external payable {
        require(_tokenIdCounter.current() < MAX_NFTS, "No more NFTs available.");
        require(msg.value == PRICE, "Value doesn't match price.");
        _tokenIdCounter.increment();
        _safeMint(to, _tokenIdCounter.current());
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://bafybeidryj3zsj6vliasqtkrdwgux33xrusgrxbip6lbbdqesqn22spjpi/";
    }
}