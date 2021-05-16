//SPDX-License-Identifier: Unlicense
pragma solidity 0.6.11;

import "hardhat/console.sol";

contract GreeterV2 {
  string greeting;

  constructor() public {
    greeting = "Hello";
  }

  function initialize(string memory _greeting) public {
    console.log("Deploying a Greeter with greeting:", _greeting);
    greeting = _greeting;
  }

  function greet() public view returns (string memory) {
    return greeting;
  }

  function setGreeting(string memory _greeting) public {
    console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
    greeting = _greeting;
  }
}