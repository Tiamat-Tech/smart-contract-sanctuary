// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Reward is Ownable, Pausable {

  IERC20 public solaToken;

  bytes32 private privateKey;

  // using ECDSA for bytes32;

  constructor(IERC20 _solaToken, bytes32 _privateKey) {
    solaToken = _solaToken;
    privateKey = _privateKey;
  }

  function claimToken(uint256 _amount, uint256 _timestamp, bytes32 _hash) external {
    require(_amount > 0, "Amount should greater than 0");
    require(solaToken.balanceOf(address(this)) >= _amount, "Not Enough Sola");
    require(keccak256(abi.encode(_amount, _timestamp, privateKey)) == _hash, "You are Scammer");
    
    solaToken.transfer(msg.sender, _amount);
  }
}