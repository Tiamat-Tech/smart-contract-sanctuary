//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DummyToken is ERC20, Ownable, AccessControl {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

  constructor(string memory token, string memory symbol) ERC20(token, symbol) {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function mint(address account, uint256 amount) public {
     require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) public {
     require(hasRole(BURNER_ROLE, msg.sender), "Caller is not a burner");
    _burn(account, amount);
  }
}