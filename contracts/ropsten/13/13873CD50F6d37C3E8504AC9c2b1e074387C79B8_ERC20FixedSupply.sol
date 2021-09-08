// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ERC20.sol";
import "./ERC20Ownable.sol";

contract ERC20FixedSupply is ERC20 {
  //mapping(address => uint256) balances;
  mapping(address => mapping(address => uint256)) allowed;

  constructor(
    address _owner,
    string memory name,
    string memory symbol,
    uint8 decimal,
    uint256 initialSupply
  ) ERC20(name, symbol, decimal) {
    require(_owner != address(0));
    //owner = _owner;

    _mint(_owner, initialSupply);
    _totalSupply = initialSupply * 10**uint8(decimal);
    _balances[_owner] = _totalSupply;
    emit Transfer(address(0), _owner, _totalSupply);
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