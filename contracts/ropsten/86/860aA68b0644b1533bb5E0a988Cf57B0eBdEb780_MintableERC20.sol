// SPDX-License-Identifier: NONE

pragma solidity ^0.8.0;

import "./ERC20/ERC20Permit.sol";
import "./utils/Ownable.sol";

/**
 * @title Mintable ERC20
 * @author crypto-pumpkin
 */
contract MintableERC20 is ERC20Permit, Ownable {

  uint256 public mintAmount = 100000 ether;
  uint256 public capMultiplierPerAccount = 5;

  constructor (
    string memory _name,
    string memory _symbol,
    uint8 _decimals
  ) ERC20(_name, _symbol, _decimals) ERC20Permit(_name) {
  }

  function setMintAmount(uint256 _newCap, uint256 _newAmount) public onlyOwner {
    capMultiplierPerAccount = _newCap;
    mintAmount = _newAmount;
  }

  function mint() public {
    require(_balances[msg.sender] < capMultiplierPerAccount * mintAmount, "Pumpkin: dont be greedy!");
    _mint(msg.sender, mintAmount);
  }
}