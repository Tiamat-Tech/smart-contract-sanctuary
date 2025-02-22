// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract NFT721 is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address owner;
    
    constructor() public ERC721("NFT721", "AAA") {
        owner = msg.sender;
    }

    function awardItem(address player, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);
        return newItemId;
    }
}