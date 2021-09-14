//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC721Mint.sol";

contract ERC721Mintable is ERC721Mint{
    constructor(string memory tokenName, string memory symbol)
    ERC721(tokenName, symbol)
  {
    _setBaseURI("ipfs://");
  }
}