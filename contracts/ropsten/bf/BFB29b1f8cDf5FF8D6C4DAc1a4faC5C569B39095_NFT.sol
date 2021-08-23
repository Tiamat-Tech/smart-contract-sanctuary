//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract NFT is ERC1155 {
    uint256 public constant SWORD = 0;
    
    constructor() ERC1155("https://lqm5lovruqm4.moralisweb3.com:2053/server/functions/getNFT?_ApplicationId=Qi4MG7rKbOcGL4ZOnvhY5cMKbCiARwN5yxjnUTpL&id={id}") {
        _mint(msg.sender, SWORD, 1, "");
    }

}