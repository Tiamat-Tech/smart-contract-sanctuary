// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract SocialNft is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter tokenIds;

    constructor() ERC721("SocialNFT", "SNFT") {}

    function mintToken(string memory _tokenURI) external {
        tokenIds.increment();
        uint256 _newItemId = tokenIds.current();

        _safeMint(msg.sender, _newItemId);
        _setTokenURI(_newItemId, _tokenURI);
    }
}