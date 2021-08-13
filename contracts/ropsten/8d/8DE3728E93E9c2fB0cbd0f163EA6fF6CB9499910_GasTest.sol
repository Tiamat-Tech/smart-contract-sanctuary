//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";


contract GasTest {
  uint256 private IPFS_LENGTH = 46;

  string public baseUri;

  constructor() {}

  function setBaseUri(string calldata _uri) external {
    baseUri = _uri;
  }

  function tokenUri(uint256 _id) external view returns (string memory){
    uint256 startIndex = _id * IPFS_LENGTH + 1;

    bytes memory uri = new bytes(IPFS_LENGTH + 1);
    for(uint i = 0; i <= IPFS_LENGTH; i++) {
      uri[i] = bytes(baseUri)[i + startIndex - 1];
    }

    return string(uri);
  }
}