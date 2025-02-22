//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract NFT is ERC1155 {
    uint256 public constant SWORD = 0;
    
    constructor() ERC1155("https://lqm5lovruqm4.moralisweb3.com/{id}.json") {
        _mint(msg.sender, SWORD, 1, "");
    }

}