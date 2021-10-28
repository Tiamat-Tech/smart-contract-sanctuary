// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract MyNFT is ERC721PresetMinterPauserAutoId {
       constructor() ERC721PresetMinterPauserAutoId("GBB NFT", "GBB", "http://mars.muzamint.com:3002/") {
       mint(0xA7042de62a3bC6e40724d5A804F86bfDB1BfA4F2);// mint the first token to someone for example
    }
}