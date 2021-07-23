//SPDX-License-Identifier: Unlicense

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IEthPool.sol";

contract EthPool is IEthPool {

    using SafeMath for uint256;

    modifier withValueEqualsTo(uint256 _amount) {
        require(_amount == msg.value, "Amount must match value sent");
        _;
    }

    event StakeDeposited(address indexed _staker, uint256 _amount, uint256 _totalAmount, uint256 _date);
    event Withdrawn(address indexed _staker, uint256 _unstakedAmount, uint256 _rewardsAmount, uint256 _date);
    event RewardsDeposited(
        uint256 indexed _rewardId,
        address indexed _rewarder,
        uint256 _amountDeposited,
        uint256 _amountDistributed,
        uint256 _date
    );

    struct StakerData {
        uint256 index;
        uint256 stakedAmount;
        uint256 rewardAmount;
    }

    address public rewarder;
    address[] public stakers;
    uint256 public totalStakedAmount;
    uint256 public totalDepositedRewards;
    uint256 nextRewardId;

    mapping(address => StakerData) stakersData;

    constructor() {
        rewarder = msg.sender;
    }

    /**
     * @dev Stakes ETH in the pool.
     * @param _amount The amount of ETH to stake, must match the value sent.
     * @return The total amount of ETH currently staked by the sender in the pool.
     */
    function stake(uint256 _amount) external override payable withValueEqualsTo(_amount) returns (uint256) {
        require(_amount > 0, "Amount to stake must be greater than zero");
        if (stakersData[msg.sender].stakedAmount == 0) {
            stakersData[msg.sender].index = stakers.length;
            stakers.push(msg.sender);
        }
        uint256 totalStakedAmountBySender = stakersData[msg.sender].stakedAmount.add(_amount);
        totalStakedAmount = totalStakedAmount.add(_amount);
        stakersData[msg.sender].stakedAmount = totalStakedAmountBySender;
        emit StakeDeposited(msg.sender, _amount, totalStakedAmountBySender, block.timestamp);
        return totalStakedAmountBySender;
    }

    /**
     * @dev Deposits ETH to reward stakers in the pool.
     * @param _amount The amount of ETH to deposit, must match the value sent.
     */
    function depositRewards(uint256 _amount) external override payable withValueEqualsTo(_amount) {
        require(msg.sender == rewarder, "Sender must be allowed as rewarder");
        uint256 distributedRewards;
        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 reward = _amount.mul(stakersData[staker].stakedAmount).div(totalStakedAmount);
            stakersData[staker].rewardAmount = stakersData[staker].rewardAmount.add(reward);
            distributedRewards = distributedRewards.add(reward);
        }
        if (_amount - distributedRewards > 0) {
            (bool returnSucceed, ) = msg.sender.call{value: _amount - distributedRewards}("");
            require(returnSucceed, "Transfer failed");
        }
        totalDepositedRewards = totalDepositedRewards.add(distributedRewards);
        emit RewardsDeposited(nextRewardId++, msg.sender, _amount, distributedRewards, block.timestamp);
    }

    /**
     * @dev Withdraws stakes and rewards from the pool.
     * @return The total amount of ETH withdrawn, including both stakes and rewards.
     */
    function withdraw() external override returns (uint256) {
        require(stakersData[msg.sender].stakedAmount > 0, "Only stakers can withdraw");
        uint256 withdrawerIndex = stakersData[msg.sender].index;
        uint256 unstakedAmount = stakersData[msg.sender].stakedAmount;
        uint256 rewardsWithdrawn = stakersData[msg.sender].rewardAmount;
        address lastStaker = stakers[stakers.length - 1];
        stakers[withdrawerIndex] = lastStaker;
        stakers.pop();
        stakersData[lastStaker].index = withdrawerIndex;
        stakersData[msg.sender].index = 0;
        stakersData[msg.sender].stakedAmount = 0;
        stakersData[msg.sender].rewardAmount = 0;
        (bool withdrawSucceed, ) = msg.sender.call{value: unstakedAmount + rewardsWithdrawn}("");
        require(withdrawSucceed, "Transfer failed");
        emit Withdrawn(msg.sender, unstakedAmount, rewardsWithdrawn, block.timestamp);
        return unstakedAmount + rewardsWithdrawn;
    }

    /**
     * @dev Gets the current ETH staked by the given address.
     * @param _staker The address to which the balance is queried.
     * @return The amount of ETH currently staked by the given address.
     */
    function getStakedAmountBy(address _staker) external view returns (uint256) {
        return stakersData[_staker].stakedAmount;
    }
}