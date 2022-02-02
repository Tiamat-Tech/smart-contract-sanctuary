// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract XpToken is ERC20, Ownable {
  address public minter;

  constructor() ERC20("XP", "XP") {}

  function mint(address _recipient, uint256 _amount) public {
    require(msg.sender == minter, "not a minter");
    _mint(_recipient, _amount);
  }

  function burn(address _account, uint256 _amount) public {
    require(allowance(_account, msg.sender) >= _amount, "not allowed to burn");
    _burn(_account, _amount);
    _approve(_account, msg.sender, allowance(_account, msg.sender) - _amount);
  }

  function passMinterRole(address _minter) public onlyOwner {
    require(isContract(_minter), "minter should be a contract");
    minter = _minter;
  }

  function isContract(address account) internal view returns (bool) {
    uint256 size;
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }
}