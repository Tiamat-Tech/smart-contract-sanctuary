// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 NOTE: NOT A PRODUCTION CONTRACT. ONLY USED IN INTERNAL TESTING. UNAUDITED AND PROVIDED WITHOUT CHECKS.
 */

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SampleNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("GameItem", "ITM") {}

    function mint(address player) public returns (uint256) {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        return newItemId;
    }
}