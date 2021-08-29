// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import './extensions/ERC20Burnable.sol';

contract ERC20Burn is ERC20Burnable {
  string public _name;
  string public _symbol;
  uint256 _initialSupply;
  uint8 _decimal;

  constructor(
    address owner,
    string memory name,
    string memory symbol,
    uint8 decimal,
    uint256 initialSupply
  ) ERC20Standard(name, symbol, decimal) {
    _mint(owner, initialSupply);
    _totalSupply = initialSupply  *  10  ** uint8(decimal);
    
  }

  function init(
    string memory name,
    string memory symbol,
    uint8 decimal,
    uint256 initialSupply
  ) public {
    _name = name;
    _symbol = symbol;
    _decimal = decimal;
    _initialSupply = initialSupply;
  }
}