// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ETHPool is Ownable {
    using SafeMath for uint256;

    uint256 public totalStaked;
    uint256 public rewardPerToken;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public discountRewardsForBalances;

    event Stake(address payable indexed staker, uint256 amount);
    event Deposit(uint256 amount);
    event WithdrawBalanceAndRewards(address indexed unstaker, uint256 amount, uint256 rewards);

    /**
     * TODO: describe methods
     */
    function stake() external payable {
        require(msg.value > 0, "The amount to staked should be greater than zero.");
        balances[msg.sender] += msg.value;
        discountRewardsForBalances[msg.sender] = discountRewardsForBalances[msg.sender].add(rewardPerToken.mul(msg.value));
        totalStaked += msg.value;

        emit Stake(payable(msg.sender), msg.value);
    }

    /**
     * TODO: describe methods
     */
    function deposit() external payable onlyOwner {
        require(msg.value > 0, "The amount of rewards should be greater than zero.");
        require(totalStaked > 0, "The amount of total balance should be greater than zero.");
        rewardPerToken = rewardPerToken.add(msg.value.div(totalStaked));

        emit Deposit(msg.value);
    }

    /**
     * TODO: describe methods
     */
    function withdrawBalanceAndRewards() external {
        require(balances[msg.sender] > 0, "The amount of staked should be greater than zero.");

        uint256 _balance = balances[msg.sender];
        uint256 _rewards = _balance.mul(rewardPerToken);
        uint256 _rewardsWithDiscount  = _rewards.sub(discountRewardsForBalances[msg.sender]);
        uint256 _transferAmount = _balance.add(_rewardsWithDiscount);

        balances[msg.sender] = 0;
        discountRewardsForBalances[msg.sender] = 0;
        totalStaked -= _balance;
        payable(msg.sender).transfer(_transferAmount);

        emit WithdrawBalanceAndRewards(msg.sender, _balance, _rewardsWithDiscount);
    }
}