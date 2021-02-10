// SPDX-License-Identifier: MIT
pragma solidity >=0.6.8 <0.8.0;

import "./ERC20DynamicSupply.sol";

contract ERC20AccessControl is ERC20DynamicSupply {
  using SafeMath for uint256;

  uint32 internal constant FUNC_ADD_ADMIN = 8;
  uint32 internal constant FUNC_REMOVE_ADMIN = 9;

  event AdminAdd(address indexed account, uint256 timestamp);
  event AdminRemove(address indexed account, uint256 timestamp);

  mapping(address => bool) _admins;

  constructor(
    string memory tokenName,
    string memory tokenSymbol,
    uint8 tokenDecimals,
    uint256 tokenTotalSupply
  ) ERC20DynamicSupply(tokenName, tokenSymbol, tokenDecimals, tokenTotalSupply) {
    _admins[owner()] = true;
  }

  function isAdmin(address account) public view virtual returns (bool) {
    return _admins[account];
  }

  function addAdmin(address account) external virtual whenNotPaused returns (bool) {
    require(!isLockedAccount(account), "ERC20: account locked");
    _checkAccess(FUNC_ADD_ADMIN);

    _admins[account] = true;
    emit AdminAdd(account, block.timestamp);

    return true;
  }

  function removeAdmin(address account) external virtual whenNotPaused returns (bool) {
    _checkAccess(FUNC_REMOVE_ADMIN);

    if (!_admins[account]) return false;

    _admins[account] = false;
    emit AdminRemove(account, block.timestamp);

    return true;
  }

  function _checkAccess(uint32 func) internal virtual override {
    if (
      func == FUNC_ADD_ADMIN ||
      func == FUNC_REMOVE_ADMIN ||
      func == FUNC_INC_SUPPLY ||
      func == FUNC_DEC_SUPPLY ||
      func == FUNC_MINT ||
      func == FUNC_PAUSE ||
      func == FUNC_UNPAUSE
    ) {
      require(msg.sender == owner(), "ERC20: caller must be owner");
    }

    if (func == FUNC_LOCK_ACCOUNT || func == FUNC_UNLOCK_ACCOUNT) {
      require(isAdmin(msg.sender), "ERC20: caller must be admin");
    }
  }
}