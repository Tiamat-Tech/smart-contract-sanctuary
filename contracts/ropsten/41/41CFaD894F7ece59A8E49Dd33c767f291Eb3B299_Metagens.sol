//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Metagens is ERC1155{
    uint256 public constant GOLD = 0;
    uint256 public constant SILVER = 1;

    constructor() public ERC1155("https://game.example/api/item/{id}.json") {
        console.log("Deploying Metagens");
        _mint(msg.sender, GOLD, 10**18, "");
        _mint(msg.sender, SILVER, 10**27, "");
    }
}