// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";

contract Greeter is ERC20PermitUpgradeable {
  string greeting;

  function initialize(string memory _greeting) public initializer {
      __ERC20Permit_init("Swift Vault");
      
      greeting = _greeting;
  }

  function greet() public view returns (string memory) {
    return greeting;
  }

  function setGreeting(string memory _greeting) public {
    greeting = _greeting;
  }
}