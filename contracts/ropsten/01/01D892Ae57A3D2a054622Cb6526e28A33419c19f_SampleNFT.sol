// SPDX-License-Identifier: MIT
// @unsupported: ovm

pragma solidity ^0.6.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SampleNFT is ERC721 {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) public {
    }

    function mintNft(address _to, string memory tokenURI) public returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _safeMint(_to, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}