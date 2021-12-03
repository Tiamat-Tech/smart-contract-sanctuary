// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IDarenBonus.sol";

contract DarenBonus is IDarenBonus, Initializable, PausableUpgradeable {
  using SafeMathUpgradeable for uint256;

  address public darenToken;
  address public setter;

  uint256 public totalTransactionAmount;
  uint256 public allocRatioBase; // 1 / 2
  uint256 public allocRatio;

  uint256 public usdtExchangeRate; // 1:1
  uint256 public usdtExchangeRateBase;

  // struct UserBonus {
  //     uint transactionAmount;
  //     uint rewardableAmount;
  //     uint blockNumber;
  // }

  mapping(address => uint256) public userBonus;
  mapping(address => uint256) public userTotalAmount;
  mapping(address => bool) public darenOrders; // whitelist

  // constructor(address _darenToken) {
  function initialize(address _darenToken) public initializer {
    darenToken = _darenToken;

    totalTransactionAmount = 0;
    // Reward ratio: allocRatioBase / allocRatio = 1000 / 2000 =
    allocRatioBase = 1000; // 1 / 2
    allocRatio = 2000;

    usdtExchangeRate = 10**9; // 1:1
    usdtExchangeRateBase = 10**9;

    setter = msg.sender;

    darenOrders[msg.sender] = true;
  }

  function completeOrder(
    address _buyer,
    address _seller,
    uint256 _value,
    uint256 _fee
  ) external override {
    require(darenOrders[msg.sender], "Invalid daren order address.");

    uint256 bonusAmount = _fee.mul(allocRatioBase).div(allocRatio);
    uint256 finalAmount = bonusAmount.mul(usdtExchangeRateBase).div(
      usdtExchangeRate
    );

    userBonus[_buyer] = userBonus[_buyer].add(finalAmount);
    userBonus[_seller] = userBonus[_seller].add(finalAmount);
    userTotalAmount[_seller] = userTotalAmount[_seller].add(_value);
    totalTransactionAmount = totalTransactionAmount.add(_value);
    emit OrderCompleted(_buyer, _seller, _value, _fee);
  }

  function voteToCompleteOrder(
    address[] memory voters,
    address _buyer,
    address _seller,
    uint256 _value,
    uint256 _fee
  ) external {
    uint256 voterCount = voters.length;

    if (voterCount > 0) {
      uint256 bonusAmount = _fee.div(voterCount);
      uint256 finalAmount = bonusAmount.mul(usdtExchangeRateBase).div(
        usdtExchangeRate
      );

      for (uint256 i = 0; i < voters.length; i++) {
        userBonus[voters[i]] = userBonus[voters[i]].add(finalAmount);
      }
    }

    userTotalAmount[_seller] = userTotalAmount[_seller].add(_value);
    totalTransactionAmount = totalTransactionAmount.add(_value);
    emit OrderCompleted(_buyer, _seller, _value, _fee);
  }

  function getCurrentReward() external view override returns (uint256) {
    uint256 bonus = userBonus[msg.sender];
    return bonus;
  }

  function getRewardOf(address _account)
    external
    view
    override
    returns (uint256)
  {
    return userBonus[_account];
  }

  function withdrawReward() external override {
    uint256 bonus = userBonus[msg.sender];
    ERC20 dt = ERC20(darenToken);
    require(dt.balanceOf(address(this)) > bonus, "Withdraw is unavailable now");

    uint256 reward = bonus;
    require(reward > 0, "You have no bonus.");
    if (reward > 0) {
      userBonus[msg.sender] = 0;
      dt.transfer(msg.sender, reward);
      emit RewardWithdrawn(msg.sender, reward);
    }
  }

  function setAllocRatio(uint256 _allocRatio) external {
    require(msg.sender == setter, "setAllocRatio: FORBIDDEN");
    allocRatio = _allocRatio;
  }

  function includeInDarenOrders(address _darenOrder) external {
    require(msg.sender == setter, "includeInDarenOrders: FORBIDDEN");
    darenOrders[_darenOrder] = true;
  }

  function excludeFromDarenOrders(address _darenOrder) external {
    require(msg.sender == setter, "excludeFromDarenOrders: FORBIDDEN");
    darenOrders[_darenOrder] = false;
  }

  function setUsdtExchangeRate(uint256 rate) external {
    require(msg.sender == setter, "setUsdtExchangeRate: FORBIDDEN");
    require(rate > 0, "rate must greater than 0");
    usdtExchangeRate = rate;
  }
}