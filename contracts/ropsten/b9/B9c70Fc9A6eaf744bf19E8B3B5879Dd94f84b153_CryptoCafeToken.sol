// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract CryptoCafeToken is Context, ERC20, Ownable {
  mapping(address => uint256) private _balances;

  uint256 public _totalSupply = 1000000000 * 10**18;
  string private _name;
  string private _symbol;

  constructor() ERC20("CryptoCafe", "CCAF") {
    address develop = address(0x7ea07F2254f05aEe20513DE3e131E462c7ACb6d2);

    _mint(msg.sender, 800000000 * 10**18); //game rewards
    _mint(develop, 200000000 * 10**18); //develop
  }

  function setMaxSupply(uint256 maxSupply) external onlyOwner {
    require(maxSupply > 0, "this string should not empty");
    _totalSupply = maxSupply;
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