//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract AdminStorage {

  /// @notice Administrator for the contract
  address public admin;

  /// @notice Pending administrator for the contract
  address public pendingAdmin;
  
}