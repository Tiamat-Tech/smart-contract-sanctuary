// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TestNFT is ERC721, Ownable {

    uint256 MINT_PER_BLOOT = 2;
    uint256 MAX_SUPPLY = 10000;


    constructor() public ERC721("TestNFT", "T&NFT") {
    }
}