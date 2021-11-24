// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract SoloNft is ERC721 {
    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}
}