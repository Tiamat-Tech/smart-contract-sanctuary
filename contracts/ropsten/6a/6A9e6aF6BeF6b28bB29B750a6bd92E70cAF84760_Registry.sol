// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./RegistryInterface.sol";

/// @title Interface that allows a user to draw an address using an index
contract Registry is OwnableUpgradeable, RegistryInterface {
  address private pointer;

  event Registered(address indexed pointer);

  constructor () {
    __Ownable_init();
  }

  function register(address _pointer) external onlyOwner {
    pointer = _pointer;

    emit Registered(pointer);
  }

  function lookup() external override view returns (address) {
    return pointer;
  }
}