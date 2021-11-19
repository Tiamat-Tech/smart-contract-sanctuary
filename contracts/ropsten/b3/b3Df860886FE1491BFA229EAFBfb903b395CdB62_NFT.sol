// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721, Ownable {
    uint256 public tokenCounter;

    constructor() ERC721("Gift NTF", "DNTF") {}

    function mint(address to) public returns (uint256) {
        require(balanceOf(msg.sender) == 0, "is not possible to own more than one NFT per address");
        
        uint256 newItemId = tokenCounter;
        tokenCounter = tokenCounter + 1;
        _mint(to, newItemId);
        return newItemId;
    }
}