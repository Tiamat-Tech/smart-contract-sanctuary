// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// "ZQToken", "ZQB", 1000000000
contract ZQErc20Token is ERC20, ERC20Burnable, Pausable, Ownable {
  constructor(string memory _name, string memory _symbol, uint256 _initialSupply)
  ERC20(_name, _symbol) {
    _mint(msg.sender, _initialSupply * 10 ** decimals());
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function _beforeTokenTransfer(address from, address to, uint256 amount)
  internal
  whenNotPaused
  override
  {
    super._beforeTokenTransfer(from, to, amount);
  }
}