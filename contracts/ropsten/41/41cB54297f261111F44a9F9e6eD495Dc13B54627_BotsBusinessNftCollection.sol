//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract BotsBusinessNftCollection is ERC721 {
    constructor() ERC721("BotsBusinessNftCollection", "BBNC") {
    }
}