//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";


contract GasTest {
  mapping(uint256 => string) public baseUri;

  constructor() {}

  function setBaseUri(string[] calldata _uri) external {
    for(uint256 i = 0; i < _uri.length; i++) {
      baseUri[i] = _uri[i];
    }
  }
}