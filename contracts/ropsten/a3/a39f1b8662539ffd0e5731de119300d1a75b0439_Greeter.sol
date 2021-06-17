/**
 *Submitted for verification at Etherscan.io on 2021-06-17
*/

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


contract Greeter {
  string greeting;
  constructor() {
    greeting = 'Hello, World';
  }

  function greet() public view returns (string memory) {
    return greeting;
  }

  function setGreeting(string memory _greeting) public {
    greeting = _greeting;
  }
}