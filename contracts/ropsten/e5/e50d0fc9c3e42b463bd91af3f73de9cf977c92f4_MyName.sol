// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./MyNameOne.sol";

contract MyName {
  uint public cccc;

  function setWeight(uint _weight) public {
    cccc = _weight;
  }
}