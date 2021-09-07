// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFTCard is ERC721URIStorage {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("RubricCardTEST", "RUBT") {}

    function createToken(string memory tokenURI) public returns (uint) {
        //Increment the number of tokens
        _tokenIds.increment();
        //Set this item's ID
        uint256 newItemId = _tokenIds.current();
        //Mint this item
        _mint(msg.sender, newItemId);
        //Set the tokenURI of this NFT
        _setTokenURI(newItemId, tokenURI);
        //Return the item's ID
        return newItemId;
    }
}