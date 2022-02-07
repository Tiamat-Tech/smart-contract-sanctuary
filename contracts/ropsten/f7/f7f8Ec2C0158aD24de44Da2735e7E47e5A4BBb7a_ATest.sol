// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ATest is ERC721{
    constructor() ERC721("Hello", "hi"){

    }
}