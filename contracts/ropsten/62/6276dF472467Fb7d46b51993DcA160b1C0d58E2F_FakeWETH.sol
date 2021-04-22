// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FakeWETH is ERC20, AccessControl {
  bytes32 public constant NO_LIMIT_ROLE = keccak256("NO_LIMIT_ROLE");

  address payable public owner;

  mapping(address => uint256) lastIssuedTime;

  constructor(address swapManagerAddress) ERC20("FakeWETH", "fWETH") {
    owner = payable(msg.sender);
    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(NO_LIMIT_ROLE, _msgSender());
    grantRole(NO_LIMIT_ROLE, swapManagerAddress);
  }

  function burn(uint256 amount) public {
    _burn(msg.sender, amount);
  }

  function mintForUser(address user, uint256 amount) external {
    require(
      hasRole(NO_LIMIT_ROLE, _msgSender()),
      "SwapManager: must have NO_LIMIT_ROLE role to mint tokens for an address"
    );
    _mint(user, amount);
  }
}