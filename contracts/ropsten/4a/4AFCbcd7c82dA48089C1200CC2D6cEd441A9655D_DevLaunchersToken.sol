// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract DevLaunchersToken is ERC777, AccessControl {

  bytes32 public constant MINTER_ROLE = keccak256("MINTER");
  bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");

  constructor(address[] memory _defaultOperators)
    ERC777("DEVS", "DEVS", _defaultOperators)
    {
      _setRoleAdmin(MINTER_ROLE, ADMIN_ROLE);
      _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
      _setupRole(ADMIN_ROLE, msg.sender);
    }

    function mint(address receiver, uint256 amount, bytes calldata userData, bytes calldata operatorData) public onlyRole(MINTER_ROLE) {
      _mint(receiver, amount, userData, operatorData);
    }

}