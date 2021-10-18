// contracts/XNft.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract inefte is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

}