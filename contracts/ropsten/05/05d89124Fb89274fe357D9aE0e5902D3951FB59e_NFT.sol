//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFT is ERC721{
    uint256 public constant SWORD = 0;

    constructor() ERC721("OBOJAMA", "OBJ"){
    }
}