// SPDX-License-Identifier: MIT

// contracts/SimpleToken.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}


contract RToken is ERC20,Ownable, ReentrancyGuard {

    using SafeMath for uint;
    address public donationWallet=0xec198294f5233b8A22a07Fb8B865a5587169616b;
    address public liquidityWallet=0xec198294f5233b8A22a07Fb8B865a5587169616b;
    /**
     * @dev Constructor that gives msg.sender all of existing tokens.
     */
    string _name='ROSSTOKEN';
    string  _symbol='LQT';
    uint256 initialSupply=1000000000000000000000000000;
    uint256 donationFee=100; //100 is 1 percent, 50 is 0.5 percent and 125 is 1.25 percent
    uint256 liquidityFee=100;
    uint256 burnFee=50;
    bool public isFeeEnabled=false;
    uint256 public totalBurnAmount;
    uint256 public totalDonationAmount;
    uint256 public totalLiquidityAmount;
    uint256 public totalFeeAmount;
    constructor()  ERC20(_name, _symbol) {
        _mint(msg.sender, initialSupply);
    }
    function setDonationWallet(address wallet) public onlyOwner returns (bool) {
        donationWallet=wallet;
        return true;
    }
    function setLiquidityWallet(address wallet) public onlyOwner returns (bool) {
        liquidityWallet=wallet;
        return true;
    }
    function setFeeEnbled(bool enabled) public onlyOwner returns (bool) {
        isFeeEnabled=enabled;
        return true;
    }
    function transferWithFee(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, collectFee(amount));
        return true;
    }
    function getBurnFee() public view returns (uint256) {
        if (isFeeEnabled)
          return liquidityFee;
        else
          return 0;
    }
    function getLiquidityFee() public view returns (uint256) {
        if (isFeeEnabled)
          return burnFee;
        else
          return 0;
    }
    function getDonationFee() public view returns (uint256) {
        if (isFeeEnabled)
          return donationFee;
        else
          return 0;
    }
    function collectFee(uint256 amount) internal returns (uint256){
        uint256 tokensToTransfer = amount;
        if(isFeeEnabled){
          uint256 burnAmount = amount.mul(burnFee).div(10000);
          uint256 donationAmount = amount.mul(donationFee).div(10000);
          uint256 liquidityAmount = amount.mul(liquidityFee).div(10000);
          totalBurnAmount = totalBurnAmount.add(burnAmount);
          totalDonationAmount = totalDonationAmount.add(donationAmount);
          totalLiquidityAmount = totalLiquidityAmount.add(liquidityAmount);
          totalFeeAmount = totalFeeAmount.add(burnAmount);
          totalFeeAmount = totalFeeAmount.add(donationAmount);
          totalFeeAmount = totalFeeAmount.add(liquidityAmount);
          tokensToTransfer = amount.sub(burnAmount);
          tokensToTransfer = tokensToTransfer.sub(donationAmount);
          tokensToTransfer = tokensToTransfer.sub(liquidityAmount);
          _burn(_msgSender(),burnAmount);
          _transfer(_msgSender(), donationWallet, donationAmount);
          _transfer(_msgSender(), liquidityWallet, liquidityAmount);
        }
        return tokensToTransfer;
    }
    function burn(uint256 amount) public returns (bool) {
        _burn(_msgSender(),amount);
        return true;
    }
    function donate(uint256 amount) public returns (bool) {
        _transfer(_msgSender(), donationWallet, amount);
        return true;
    }

    function transferFromWithFee(address recipient, uint256 amount) public returns (bool) {
        transferFrom(_msgSender(), recipient, collectFee(amount));
        return true;
    }
}