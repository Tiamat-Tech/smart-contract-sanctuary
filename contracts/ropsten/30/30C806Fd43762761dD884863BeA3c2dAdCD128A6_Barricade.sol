//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Barricade is ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    uint256 public constant price = 0.04 ether;
    uint256 public constant total = 8888;

    uint256 public constant maxPerTxn = 10;
    bool public saleIsActive = false;

    constructor() ERC721("Barricade", "BAR") {}
}