// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract CryptoCafeToken is Context, ERC20, Ownable {
  mapping(address => uint256) private _balances;

  uint256 public _maxSupply = 1000 * 10**18;
  string private _name;
  string private _symbol;

  constructor() ERC20("CryptoCafe", "CCAF") {
    _balances[msg.sender] = _maxSupply;
  }

  function setMaxSupply(uint256 maxSupply) external onlyOwner {
    require(maxSupply > 0, "this string should not empty");
    _maxSupply = maxSupply;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
  {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  function approve(address spender, uint256 amount)
    public
    override
    returns (bool)
  {
    _approve(_msgSender(), spender, amount);
    return true;
  }
}