// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.4;

import "hardhat/console.sol";

contract Set {
  uint256 public one;
  uint256 public two;
  uint256 public three;

  address public owner;

  constructor(address _owner) {
    owner = _owner;
  }

  modifier authorised() {
    console.log("test change");
    console.log("this is the sender:");
    console.log(msg.sender);
    console.log("this is the owner:");
    console.log(owner);
    console.logBool(msg.sender == owner);
    require(msg.sender == owner);
    _;
  }

  function setOne(uint256 number) public {
    one = number;
  }

  function setTwo(uint256 number) public authorised {
    two = number;
  }

  function setThree(uint256 number) public authorised {
    three = number;
  }

  function getNumbers()
    public
    view
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    return (one, two, three);
  }
}