// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.3;

import "hardhat/console.sol";

import "./Ownable.sol";

contract Box is Ownable {
  uint private _value;

  event ValueChanged(uint newValue);

  constructor(uint initialValue) {
    _value = initialValue;
  }

  function setValue(uint newValue) public onlyOwner {
    console.log("setting value to '%s'", newValue);
    _value = newValue;
    emit ValueChanged(newValue);
  }

  function getValue() public view returns (uint) {
    console.log("getting value '%s'", _value);
    return _value;
  }
}