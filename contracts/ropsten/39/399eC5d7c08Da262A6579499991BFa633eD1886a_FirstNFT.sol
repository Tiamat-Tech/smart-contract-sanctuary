//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract FirstNFT is ERC721{
     constructor() ERC721("MyFirst", "First") {}
}