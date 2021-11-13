// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NewFlokid.sol";

contract FlokiDoge is FlokidERC20 {
  uint256 private constant CAP = 8_888_888_888 * 100_000_000_000;

  constructor() FlokidERC20("FlokiDoge2", "FLOKID2", 2, CAP) {
    _whiteList[_msgSender()] = true;
    _mint(_msgSender(), CAP);
  }

  function isWhiteListed(address account) external view returns (bool) {
    return _whiteList[account];
  }

  function setTradeLimit(uint256 amount) external onlyOwner() {
    tradeLimit = amount;
  }

  function changeBurningPercent(uint256 percent) external onlyOwner() {
    burningPercent = percent;
  }

  function whitelistAccount(address account) external onlyOwner() {
    require(!_whiteList[account], "Flokid: Account is already whitelisted");
    _whiteList[account] = true;
  }

  function removeWhitelistedAccount(address account) external onlyOwner() {
    require(_whiteList[account], "Flokid: Account is not whitelisted");
    _whiteList[account] = false;
  }

  function manualSync() external {
    ILiquidityPool(pair).sync();
  }
}