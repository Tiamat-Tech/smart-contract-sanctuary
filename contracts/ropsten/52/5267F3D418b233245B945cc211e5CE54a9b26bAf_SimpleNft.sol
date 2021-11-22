// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract SimpleNft is ERC721 {
    
    constructor () ERC721 ("Thank you for contributing", "TY"){}

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;


    
    function mint(address to) public returns (uint256) {
        _tokenIdCounter.increment();
        _safeMint(to, _tokenIdCounter.current());

        return _tokenIdCounter.current();
    }

    }