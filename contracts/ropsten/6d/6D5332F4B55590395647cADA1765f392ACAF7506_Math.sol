//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Math {
  function doSum(uint a, uint b) public pure returns (uint sum) {
    return a * b;
  }
}