// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TrustlessContract is Context, Ownable {

  uint256 lockStart;
  uint256 lockEnd;
  uint256 unlockPrice;
  bool unlocked = false;

  //address USDT = 0xdac17f958d2ee523a2206206994597c13d831ec7;
  //address USDC = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48;

  address[] private _stableTokens = [0xdAC17F958D2ee523a2206206994597C13D831ec7, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48];
  mapping(address => bool) public stableTokens;

  constructor(uint256 _lockStart, uint256 _lockEnd, uint256 _unlockPrice) {
    lockStart = _lockStart;
    lockEnd = _lockEnd;
    unlockPrice = _unlockPrice;
    for (uint256 i = 0; i < _stableTokens.length; i++) {
      stableTokens[_stableTokens[i]] = true;
    }
  }

  function unlock(address _stableToken) public onlyOwner {
    require(stableTokens[_stableToken] == true, "unlock: invalid stable token address");
    IERC20 token = IERC20(_stableToken);
    require(token.balanceOf(msg.sender) >= unlockPrice, "unlock: insufficient balance");
    require(token.allowance(msg.sender, address(this)) >= unlockPrice, "unlock: insufficient allowance");
    unlocked = true;
  }

  function withdrawETH(uint256 _amount) public onlyOwner {
    require((_amount == 0 && address(this).balance > 0) || address(this).balance >= _amount, "withdrawETH: invalid amount");
    address payable _sender = payable(msg.sender);
    _sender.transfer(_amount);
  }

  function withdrawToken(address _token, uint256 _amount) public onlyOwner  {
    IERC20 token = IERC20(_token);
    require((_amount == 0 && token.balanceOf(address(this)) > 0) || token.balanceOf(address(this)) >= _amount, "withdrawToken: invalid amount");
    token.transfer(msg.sender, _amount);
  }

  function getTokenBalance(address _token) public view returns (uint256) {
    IERC20 token = IERC20(_token);
    return token.balanceOf(address(this));
  }
}