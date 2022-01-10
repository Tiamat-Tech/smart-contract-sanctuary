// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FeeToken is ERC20, Ownable {
  using SafeMath for uint256;

  address public fundWallet;
  mapping(address => bool) public blacklists;

  uint256 public constant DENOMINATOR = 10000;
  uint256 public burnFee = 0; // 1 for 0.01%, 100 for 1%
  uint256 public fundFee = 0; // 1 for 0.01%, 100 for 1%

  constructor(address payable _fundWallet) ERC20("FeeToken", "FTK") {
    _mint(msg.sender, 10**10 * 10**decimals());
    fundWallet = _fundWallet;
  }

  modifier whitelisted(address account) {
    require(!blacklists[account], "Account is blacklisted");
    _;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override whitelisted(from) whitelisted(to) {
    require(!blacklists[from] && !blacklists[to], "blacklisted");
    if (from != address(0) && from != fundWallet) {
      uint256 burnAmount = feeAmount(amount, burnFee);
      uint256 fundAmount = feeAmount(amount, fundFee);
      if (burnAmount > 0) _burn(from, burnAmount);
      if (fundAmount > 0) super._transfer(from, fundWallet, fundAmount);
    }
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    if (from != fundWallet) {
      uint256 totalFeeAmount = feeAmount(amount, burnFee.add(fundFee));
      uint256 finalAmount = amount.sub(totalFeeAmount);
      super._transfer(from, to, finalAmount);
    } else {
      super._transfer(from, to, amount);
    }
  }

  function feeAmount(uint256 _amount, uint256 _fee)
    public
    pure
    returns (uint256)
  {
    return _amount.mul(_fee).div(DENOMINATOR); // supports fee from 0.01%
  }

  function setFundFee(uint256 newFee) public onlyOwner {
    fundFee = newFee;
  }

  function setBurnFee(uint256 newFee) public onlyOwner {
    burnFee = newFee;
  }

  function blacklistAccount(address account) public onlyOwner {
    blacklists[account] = true;
  }

  function whitelistAccount(address account) public onlyOwner {
    blacklists[account] = false;
  }
}