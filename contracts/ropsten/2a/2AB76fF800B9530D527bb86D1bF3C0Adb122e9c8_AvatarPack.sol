//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract AvatarPack is ERC1155 {
 uint256 public constant GOLD = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant THORS_HAMMER = 2;
    uint256 public constant SWORD = 3;
    uint256 public constant SHIELD = 4;

    constructor() ERC1155("https://game.example/api/item/{id}.json") {
        _mint(address(this), GOLD, 10**3, "");
        _mint(address(this), SILVER, 10**3, "");
        _mint(address(this), THORS_HAMMER, 5, "");
        _mint(address(this), SWORD, 10**3, "");
        _mint(address(this), SHIELD, 10**3, "");
    }
}