// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TrustlessContract is Context, Ownable {

  uint256 public lockStart;
  uint256 public lockEnd;
  uint256 public unlockPrice;
  bool private unlocked = false;

  //address USDT = 0xdac17f958d2ee523a2206206994597c13d831ec7;
  //address USDC = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;

  address[] private _stableTokensMainnet = [0xdAC17F958D2ee523a2206206994597C13D831ec7, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48];
  address[] private _stableTokensRopsten = [0x516de3a7A567d81737e3a46ec4FF9cFD1fcb0136, 0x0D9C8723B343A8368BebE0B5E89273fF8D712e3C];

  constructor(uint256 _lockDuration, uint256 _unlockPrice) {
    lockStart = block.timestamp;
    lockEnd = block.timestamp + _lockDuration;
    unlockPrice = _unlockPrice;
  }

  function unlock() public onlyOwner {
    bool _balance;
    if (block.chainid == 1) {
      for (uint256 i = 0; i < _stableTokensMainnet.length; i++) {
        IERC20 token = IERC20(_stableTokensMainnet[i]);
        if (token.balanceOf(msg.sender) >= unlockPrice) {
          _balance = true;
        }
      }
    } else if (block.chainid == 3){
      for (uint256 i = 0; i < _stableTokensRopsten.length; i++) {
        IERC20 token = IERC20(_stableTokensRopsten[i]);
        if (token.balanceOf(msg.sender) >= unlockPrice) {
          _balance = true;
        }
      }
    }
    require(_balance, "unlock: insufficient balance");
    unlocked = true;
  }

  function withdrawETH(uint256 _amount) public onlyOwner {
    require(getUnlocked(), "withdrawETH: funds are locked");
    require((_amount == 0 && address(this).balance > 0) || address(this).balance >= _amount, "withdrawETH: invalid amount");
    address payable _sender = payable(msg.sender);
    _sender.transfer(_amount);
  }

  function withdrawToken(address _token, uint256 _amount) public onlyOwner {
    require(getUnlocked(), "withdrawToken: funds are locked");
    IERC20 token = IERC20(_token);
    uint256 balance = token.balanceOf(address(this));
    require((_amount == 0 && balance > 0) || balance >= _amount, "withdrawToken: invalid amount");
    if (_amount == 0) {
      token.transfer(msg.sender, balance);
    } else {
      token.transfer(msg.sender, _amount);
    }
  }

  function getTokenBalance(address _token) public view returns (uint256) {
    IERC20 token = IERC20(_token);
    return token.balanceOf(address(this));
  }

  function getUnlocked() public view returns (bool) {
    return block.timestamp < lockStart || block.timestamp > lockEnd || unlocked;
  }

  function getRemainingLockTime() public view returns (uint256) {
    if (getUnlocked()) {
      return 0;
    } else {
      return lockEnd - block.timestamp;
    }
  }

  function getUnlockTokens() public view returns (address[] memory) {
    if (block.chainid == 1) {
      return _stableTokensMainnet;
    } else if (block.chainid == 3) {
      return _stableTokensRopsten;
    }
  }

  function increaseLock(uint256 _lockDuration) public onlyOwner {
    require(getUnlocked(), "increaseLock: needs to be unlocked first");
    lockEnd = block.timestamp + _lockDuration;
    unlocked = false;
  }
}