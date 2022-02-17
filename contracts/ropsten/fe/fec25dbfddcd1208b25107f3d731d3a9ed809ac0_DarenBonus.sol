// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/IDarenBonus.sol";

contract DarenBonus is
    IDarenBonus,
    Initializable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable
{
    using SafeMathUpgradeable for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    address public darenToken;
    address public setter;

    uint256 public totalTransactionAmount;
    uint256 public allocRatioBase; // 1 / 2
    uint256 public allocRatio;

    uint256 public usdtExchangeRate; // 1:1
    uint256 public usdtExchangeRateBase;

    mapping(address => uint256) public userBonus;
    mapping(address => bool) public darenOrders; // whitelist

    // constructor(address _darenToken) {
    function initialize(address _darenToken) public initializer {
        __AccessControlEnumerable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);

        darenToken = _darenToken;

        totalTransactionAmount = 0;
        // Reward ratio: allocRatio / allocRatioBase = 1000 / 2000
        allocRatio = 1000; // 1 / 2
        allocRatioBase = 2000;

        // USDT exchange rate: 0.1usdt
        usdtExchangeRate = 10**8;
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
        // Verify the sender is daren order.

        uint256 bonusAmount = _fee.mul(allocRatio).div(allocRatioBase);
        uint256 finalAmount = bonusAmount.mul(usdtExchangeRate).div(
            usdtExchangeRateBase
        );

        userBonus[_buyer] = userBonus[_buyer].add(finalAmount);
        userBonus[_seller] = userBonus[_seller].add(finalAmount);
        totalTransactionAmount = totalTransactionAmount.add(_value);
        emit OrderCompleted(_buyer, _seller, _value, _fee);
    }

    function completeOrderByVoting(
        address[] memory voters,
        address _buyer,
        address _seller,
        uint256 _value,
        uint256 _fee
    ) external {
        require(darenOrders[msg.sender], "Invalid daren order address.");
        uint256 voterCount = voters.length;

        if (voterCount > 0) {
            uint256 bonusAmount = _fee.div(voterCount);
            uint256 finalAmount = bonusAmount.mul(usdtExchangeRate).div(
                usdtExchangeRateBase
            );

            for (uint256 i = 0; i < voters.length; i++) {
                userBonus[voters[i]] = userBonus[voters[i]].add(finalAmount);
            }
        }

        totalTransactionAmount = totalTransactionAmount.add(_value);
        emit OrderCompleted(_buyer, _seller, _value, _fee);
    }

    function getCurrentReward() external view override returns (uint256) {
        return userBonus[msg.sender];
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
        require(
            dt.balanceOf(address(this)) > bonus,
            "Withdraw is unavailable now"
        );

        uint256 reward = bonus;
        require(reward > 0, "You have no bonus.");
        dt.transfer(msg.sender, reward);
        userBonus[msg.sender] = 0;

        emit RewardWithdrawn(msg.sender, reward);
    }

    function setAllocRatio(uint256 _allocRatio) external onlyRole(ADMIN_ROLE) {
        allocRatio = _allocRatio;
    }

    function setUsdtExchangeRate(uint256 rate) external onlyRole(ADMIN_ROLE) {
        require(rate > 0, "rate must be greater than 0");
        usdtExchangeRate = rate;
    }

    function includeInDarenOrders(address _darenOrder)
        external
        onlyRole(ADMIN_ROLE)
    {
        darenOrders[_darenOrder] = true;
    }

    function excludeFromDarenOrders(address _darenOrder)
        external
        onlyRole(ADMIN_ROLE)
    {
        darenOrders[_darenOrder] = false;
    }
}