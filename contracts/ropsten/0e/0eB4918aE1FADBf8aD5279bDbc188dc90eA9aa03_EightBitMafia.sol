// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EightBitMafia is ERC721 {
    using Strings for uint256;

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}
}