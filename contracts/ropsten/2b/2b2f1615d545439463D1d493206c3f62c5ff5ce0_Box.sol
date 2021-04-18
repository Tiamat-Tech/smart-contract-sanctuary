// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.3;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "hardhat/console.sol";

contract Box is Initializable, OwnableUpgradeable {
  uint256 private value;

  event ValueChanged(uint256 newValue);

  function initialize(uint256 initialValue) public initializer {
    __Ownable_init();
    value = initialValue;
  }

  function store(uint256 newValue) public onlyOwner {
    console.log("storing new value '%s'", newValue);
    value = newValue;
    emit ValueChanged(newValue);
  }

  function retrieve() public view returns (uint256) {
    console.log("retrieving value '%s'", value);
    return value;
  }

  function sendEth() external payable {
    console.log("sent value is %s", msg.value);
  }
}