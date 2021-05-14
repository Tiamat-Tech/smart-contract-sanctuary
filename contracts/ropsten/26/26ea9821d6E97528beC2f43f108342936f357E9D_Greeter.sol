//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import 'hardhat/console.sol';

contract Greeter {
  string greeting;
  uint256 testNumber;
  address testAddress;

  constructor(
    string memory _greeting,
    uint256 _testNumber,
    address _testAddress
  ) {
    greeting = _greeting;
    testNumber = _testNumber;
    testAddress = _testAddress;
  }

  function greet() public view returns (string memory) {
    return greeting;
  }

  function getTestNumber() public view returns (uint256) {
    return testNumber;
  }

  function getAddress() public view returns (address) {
    return testAddress;
  }

  function setGreeting(string memory _greeting) public {
    console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
    greeting = _greeting;
  }
}