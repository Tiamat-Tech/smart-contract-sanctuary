// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
//import "./extensions/ERC20Burnable.sol";
import "./ERC20Ownable.sol";
import "./ERC20.sol";

contract ERC20Burnable is ERC20 {
  //mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) allowed;

  constructor(
    address _owner,
    string memory name,
    string memory symbol,
    uint8 decimal,
    uint256 initialSupply
  ) ERC20(name, symbol, decimal) {
    _mint(_owner, initialSupply);
    _totalSupply = initialSupply * 10**uint8(decimal);
    _balances[_owner] = _totalSupply;
    emit Transfer(address(0), _owner, _totalSupply);
  }

  function burn(uint256 amount) public virtual {
    _burn(_msgSender(), amount);
  }

  function burnFrom(address account, uint256 amount) public virtual {
    uint256 currentAllowance = allowance(account, _msgSender());
    require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
    unchecked {
      _approve(account, _msgSender(), currentAllowance - amount);
    }
    _burn(account, amount);
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