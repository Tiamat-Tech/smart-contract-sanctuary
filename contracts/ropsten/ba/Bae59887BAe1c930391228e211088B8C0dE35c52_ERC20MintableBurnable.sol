// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20Burnable.sol";

import "./ERC20Ownable.sol";
//import "./ERC20Mintable.sol";
import "./ERC20.sol";

contract ERC20MintableBurnable is ERC20 {
  //mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) allowed;

  uint256 private _cap;

  constructor(
    address _owner,
    uint256 cap_,
    string memory name,
    string memory symbol,
    uint8 decimal,
    uint256 initialSupply
  ) ERC20(name, symbol, decimal) {
    _cap = cap_ * 10**uint8(decimal);
    _mint(_owner, initialSupply);
    _totalSupply = initialSupply * 10**uint8(decimal);
    _balances[_owner] = _totalSupply;
  }

  function burn(uint256 amount) public virtual {
    _burn(_msgSender(), amount);
  }

  function mint(address recipient, uint256 amount) external {
    _mint(recipient, amount);
  }

  function cap() public view virtual returns (uint256) {
    return _cap;
  }

  function _mint(address account, uint256 amount) internal virtual override {
    require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
    super._mint(account, amount);
  }

  function balanceOf(address _owner) public view override returns (uint256) {
    return _balances[_owner];
  }

  function allowance(address _owner, address _spender)
    public
    view
    override
    returns (uint256)
  {
    return allowed[_owner][_spender];
  }
}