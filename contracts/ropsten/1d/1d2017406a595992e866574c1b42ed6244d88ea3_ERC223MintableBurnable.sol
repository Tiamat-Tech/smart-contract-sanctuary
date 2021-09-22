// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC223.sol";
import "../../libraries/SafeMath.sol";

contract ERC223MintableBurnable is ERC223Token {
  using SafeMath for uint256;
  mapping(address => bool) public _minters;
  uint256 private _cap;

  constructor(
    string memory tokenName,
    string memory tokenSymbol,
    uint8 decimalUnits,
    uint256 initialSupply,
    uint256 cap_
  ) ERC223Token(name, symbol, decimals, initialSupply) {
    _totalSupply = initialSupply * 10**uint256(decimalUnits);
    balances_[msg.sender] = _totalSupply;
    name = tokenName;
    decimals = decimalUnits;
    symbol = tokenSymbol;
    _cap = cap_ * 10**uint8(decimals);
  }

  modifier onlyMinter() {
    require(
      isMinter(msg.sender),
      "MinterRole: caller does not have the Minter role"
    );
    _;
  }

  function isMinter(address account) public view returns (bool) {
    return _minters[account];
  }

  function _mint(address account, uint256 amount) internal virtual override {
    require(
      ERC223Token.totalSupply() + amount <= cap(),
      "ERC20Capped: cap exceeded"
    );
    super._mint(account, amount);
  }

  function mint(address recipient, uint256 amount) external {
    _mint(recipient, amount);
  }

  function cap() public view virtual returns (uint256) {
    return _cap;
  }

  function burn(uint256 _amount) public {
    balances_[msg.sender] = balances_[msg.sender] - _amount;
    _totalSupply = _totalSupply - _amount;

    // bytes memory empty = hex"00000000";
    emit Transfer(address(0), msg.sender, _totalSupply);
  }
}