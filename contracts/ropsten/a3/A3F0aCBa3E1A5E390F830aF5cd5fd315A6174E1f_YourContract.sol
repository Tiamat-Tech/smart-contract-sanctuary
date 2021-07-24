//SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.9.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract YourContract is ERC1155 {
    uint256 public constant REACTION_0 = 0;
    uint256 public constant REACTION_1 = 1;
    uint256 public constant REACTION_2 = 2;
    uint256 public constant REACTION_3 = 3;
    uint256 public constant REACTION_4 = 4;
    uint256 public constant REACTION_5 = 5;

    constructor()
        public
        ERC1155("https://abcoathup.github.io/SampleERC1155/api/token/{id}.json")
    {
        _mint(msg.sender, REACTION_0, 10**4, "");
        _mint(msg.sender, REACTION_1, 10**4, "");
        _mint(msg.sender, REACTION_2, 10**4, "");
        _mint(msg.sender, REACTION_3, 10**4, "");
        _mint(msg.sender, REACTION_4, 10**4, "");
        _mint(msg.sender, REACTION_5, 10**4, "");
    }
}