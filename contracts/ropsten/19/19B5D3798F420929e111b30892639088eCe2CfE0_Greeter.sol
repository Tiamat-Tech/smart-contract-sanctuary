//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
  string private greeting;
  address public a;
  address public ab;
  address public abc;
  uint256 public num;

  constructor(
    string memory _greeting,
    address _a,
    address _ab,
    address _abc,
    uint256 _num
  ) {
    console.log("Deploying a Greeter with greeting:", _greeting);
    greeting = _greeting;
    a = _a;
    ab = _ab;
    abc = _abc;
    num = _num;
  }

  function greet() public view returns (string memory) {
    return greeting;
  }

  function setGreeting(string memory _greeting) public {
    console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
    greeting = _greeting;
  }
}