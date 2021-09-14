//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC721Burnable.sol";

contract ERC721Burnable_NFT is ERC721Burnable {
  constructor(string memory _name, string memory _symbol)
    ERC721(_name, _symbol)
  {}
}