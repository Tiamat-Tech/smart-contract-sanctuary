// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is Ownable {

  using SafeMath for uint256;
  using Address for address;

  address public _stakingTokenAddress;
  IERC20 public _stakingToken;
  uint256 public _stakingMagnitude;

  address public _rewardTokenAddress;
  IERC20 public _rewardToken;

  string public _name;

  constructor(address stakingToken, address rewardToken, string memory name) {
    _stakingTokenAddress = stakingToken;
    _stakingToken = IERC20(_stakingTokenAddress);
    _stakingMagnitude = _stakingToken.totalSupply();

    _rewardTokenAddress = rewardToken;
    _rewardToken = IERC20(_rewardTokenAddress);

    _name = name;
  }

  mapping(address => uint256) public _stakedAmount;
  mapping(address => uint256) public _stakeEntry;
  mapping(address => uint256) public _accured;
  uint256 public _totalStaked;
  uint256 public _totalReward;
  uint256 public _totalAccured;

  function deposit(uint256 newReward) public {
    require(_totalStaked > 0, "No one has staked yet");

    uint256 initialRewardBalance = _rewardToken.balanceOf(address(this));
    _rewardToken.transferFrom(msg.sender, address(this), newReward);
    uint256 newRewardBalance = _rewardToken.balanceOf(address(this));
    uint256 rewardReceived = newRewardBalance - initialRewardBalance;
    
    _totalReward = _totalReward + rewardReceived;
    _totalAccured = _totalAccured + rewardReceived * _stakingMagnitude / _totalStaked;
  }

  function stake(uint256 stakeAmount) public {
    require(_stakingToken.balanceOf(msg.sender) >= stakeAmount, "Insufficient balance");
    require(stakeAmount <= maxLeftToStake(msg.sender), "Staked cannot be > 50% of total holdings");

    uint256 initialStakedBalance = _stakingToken.balanceOf(address(this));
    _stakingToken.transferFrom(msg.sender, address(this), stakeAmount);
    uint256 newStakedBalance = _stakingToken.balanceOf(address(this));
    uint256 stakedReceived = newStakedBalance - initialStakedBalance;

    if(_stakedAmount[msg.sender] > 0)
      _accured[msg.sender] = currentRewards(msg.sender);

    _stakeEntry[msg.sender] = _totalAccured;
    _stakedAmount[msg.sender] = _stakedAmount[msg.sender] + stakedReceived;
    _totalStaked = _totalStaked + stakedReceived;
  }

  function unstakeAll() public {
    require(_stakedAmount[msg.sender] > 0, "You have no stake");

    _accured[msg.sender] = currentRewards(msg.sender);

    _stakingToken.transfer(msg.sender, _stakedAmount[msg.sender]);
    _totalStaked = _totalStaked - _stakedAmount[msg.sender];
    _stakedAmount[msg.sender] = _stakedAmount[msg.sender] = _stakedAmount[msg.sender];

    _stakeEntry[msg.sender] = _totalAccured;
  }

  function harvest() public {
    require(currentRewards(msg.sender) > 0, "Insufficient accured reward");

    _accured[msg.sender] = currentRewards(msg.sender);

    _rewardToken.transfer(msg.sender, _accured[msg.sender]);
    _totalReward = _totalReward - _accured[msg.sender];
    _accured[msg.sender] = _accured[msg.sender];
  }

  function currentRewards(address addy) public view returns (uint256) {
    return _accured[addy] + _calculateReward(addy);
  }

  function maxLeftToStake(address addy) public view returns (uint256) {
      if(_stakingToken.balanceOf(addy) <= _stakedAmount[addy])
        return 0;
      return _maxStakeAmount(addy).sub(_stakedAmount[addy]);
  }

  function _maxStakeAmount(address addy) public view returns (uint256) {
      return (_stakingToken.balanceOf(addy).add(_stakedAmount[addy])).div(2);
  }

  function _calculateReward(address addy) public view returns (uint256) {
    return _stakedAmount[addy] * (_totalAccured - _stakeEntry[addy]) / _stakingMagnitude;
  } 
}