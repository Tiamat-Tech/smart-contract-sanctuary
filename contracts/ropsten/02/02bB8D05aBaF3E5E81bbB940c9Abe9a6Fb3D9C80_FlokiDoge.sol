// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NewFlokid.sol";

contract FlokiDoge is FlokidERC20 {
  constructor() FlokidERC20("Floki Doge", "FLOKID") {
    super._mint(_msgSender(), cap);
  }

  function isWhiteListed(address account) public view returns (bool) {
    return _whiteList[account];
  }

  function setTradeLimit(uint256 amount) external onlyOwner() {
    TRADE_LIMIT = amount;
  }

  function changeBurningPercent(uint256 percent) public onlyOwner() {
    BURNING_PERCENT = percent;
  }

  function whitelistAccount(address account) public onlyOwner() {
    require(!_whiteList[account], "Flokid: Account is already whitelisted");
    _whiteList[account] = true;
  }

  function removeWhitelistedAccount(address account) public onlyOwner() {
    require(_whiteList[account], "Flokid: Account is not whitelisted");
    _whiteList[account] = false;
  }
}