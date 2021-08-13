//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";


contract GasTest {
  string public baseUri;

  constructor() {}

  function setBaseUri(string calldata _uri) external {
    baseUri = _uri;
  }
}