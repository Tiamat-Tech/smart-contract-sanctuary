// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/*
 * @notice EthRewardPool exposes functions to stake Eth and receive rewards based on the time and share of staked amount.
 */
contract EthRewardPool is Ownable {
  using SafeMath for uint256;

  mapping(address => uint256) public balances;
  mapping(address => uint256) public rewardDiscount;
  uint256 public totalStaked;
  uint256 public rewardPerEth;
  uint256 public decimalFactor = 1e18;

  event Stake(address payable indexed staker, uint256 amount);
  event Withdraw(address indexed unstaker, uint256 amount, uint256 rewardsAmount);
  event DepositRewards(uint256 amount);

  function stake() external payable {
    balances[msg.sender] += msg.value;
    rewardDiscount[msg.sender] = rewardDiscount[msg.sender].add(rewardPerEth.mul(msg.value).div(decimalFactor));
    totalStaked += msg.value;

    emit Stake(payable(msg.sender), msg.value);
  }

  function depositRewards() external payable onlyOwner() {
    require(totalStaked > 0, 'Total staked should be greater than zero');
    rewardPerEth = rewardPerEth.add(msg.value.mul(decimalFactor).div(totalStaked));

    emit DepositRewards(msg.value);
  }

  function withdraw() external {
    require(balances[msg.sender] > 0, 'Balance should be greater than zero');

    uint256 userBalance = balances[msg.sender];
    uint256 rewardAmount = userBalance.mul(rewardPerEth).div(decimalFactor);
    uint256 finalRewards = rewardAmount.sub(rewardDiscount[msg.sender]);

    balances[msg.sender] = 0;
    rewardDiscount[msg.sender] = 0;
    totalStaked -= userBalance;
    payable(msg.sender).transfer(userBalance.add(finalRewards));

    emit Withdraw(msg.sender, userBalance, finalRewards);
  }

  function tvl() view external returns(uint256) {
    return totalStaked;
  }

}