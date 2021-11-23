// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/// @title Nft contract for donation platform 
/// @author Aleksandar
/// @dev Creates unique token

contract SimpleNft is ERC721 {
    
    constructor () ERC721 ("Thank you for contributing", "TY"){}

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;


    
    function mint(address to) public returns (uint256) {
        require(balanceOf(msg.sender) == 0, "You can only own one TY NFT");
        _tokenIdCounter.increment();
        _safeMint(to, _tokenIdCounter.current());

        return _tokenIdCounter.current();
    }

    }