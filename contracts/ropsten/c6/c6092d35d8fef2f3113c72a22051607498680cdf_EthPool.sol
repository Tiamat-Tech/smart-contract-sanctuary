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
        uint256 _depositedAmount,
        uint256 _distributedAmount,
        uint256 _date
    );

    struct StakerData {
        uint256 index;
        uint256 stakedAmount;
        uint256 rewardAmount;
    }

    address public rewarder;
    address[] public stakers;
    uint256 public currentlyStakedAmount;
    uint256 public rewardsNotWithdrawn;
    uint256 nextRewardId;

    mapping(address => StakerData) stakerData;

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
        if (!_isStaker(msg.sender)) {
            _addStaker(msg.sender);
        }
        uint256 totalAmountStakedBySender = stakerData[msg.sender].stakedAmount.add(_amount);
        currentlyStakedAmount = currentlyStakedAmount.add(_amount);
        stakerData[msg.sender].stakedAmount = totalAmountStakedBySender;
        emit StakeDeposited(msg.sender, _amount, totalAmountStakedBySender, block.timestamp);
        return totalAmountStakedBySender;
    }

    /**
     * @dev Deposits ETH to reward stakers in the pool.
     * @param _amount The amount of ETH to deposit, must match the value sent.
     */
    function depositRewards(uint256 _amount) external override payable withValueEqualsTo(_amount) {
        require(msg.sender == rewarder, "Sender must be allowed as rewarder");
        uint256 distributedRewards = _distributeRewards(_amount);
        if (distributedRewards < _amount) {
            _transferEther(msg.sender, _amount - distributedRewards);
        }
        rewardsNotWithdrawn = rewardsNotWithdrawn.add(distributedRewards);
        emit RewardsDeposited(nextRewardId++, msg.sender, _amount, distributedRewards, block.timestamp);
    }

    /**
     * @dev Withdraws stakes and rewards from the pool.
     * @return The total amount of ETH withdrawn, including both stakes and rewards.
     */
    function withdraw() external override returns (uint256) {
        require(_isStaker(msg.sender), "Only stakers can withdraw");
        uint256 unstakedAmount = stakerData[msg.sender].stakedAmount;
        uint256 withdrawnRewards = stakerData[msg.sender].rewardAmount;
        _removeStaker(msg.sender);
        currentlyStakedAmount -= unstakedAmount;
        rewardsNotWithdrawn -= withdrawnRewards;
        _transferEther(msg.sender, unstakedAmount + withdrawnRewards);
        emit Withdrawn(msg.sender, unstakedAmount, withdrawnRewards, block.timestamp);
        return unstakedAmount + withdrawnRewards;
    }

    /**
     * @dev Gets the current ETH staked by the given address.
     * @param _staker The address to which the balance is queried.
     * @return The amount of ETH currently staked by the given address.
     */
    function getAmountCurrentlyStakedBy(address _staker) external override view returns (uint256) {
        return stakerData[_staker].stakedAmount;
    }

    /**
     * @dev Transfers the given amount of ETH from the contract to the given address.
     * @param _to The address to which the ETH must be transfered to.
     * @param _amount The amount of ETH to be transfered.
     */
    function _transferEther(address _to, uint256 _amount) internal {
        (bool transferSucceed, ) = _to.call{value: _amount}("");
        require(transferSucceed, "Transfer failed");
    }

    /**
     * @dev Distributes the given rewards amount between stakers. The actually distributed amount can be different from 
     * the given one because of division roundings.
     * @param _amount The amount of ETH to distribute.
     * @return The amount of ETH actually distributed.
     */
    function _distributeRewards(uint256 _amount) internal returns (uint256) {
        uint256 distributedRewards;
        for (uint256 i = 0; i < stakers.length; i++) {
            address staker = stakers[i];
            uint256 reward = _amount.mul(stakerData[staker].stakedAmount).div(currentlyStakedAmount);
            stakerData[staker].rewardAmount = stakerData[staker].rewardAmount.add(reward);
            distributedRewards = distributedRewards.add(reward);
        }
        return distributedRewards;
    }

    /**
     * @dev Tells whether a given address is a staker or not.
     * @param _staker The address to verify if is a staker.
     * @return True if is a staker, false if not.
     */
    function _isStaker(address _staker) internal view returns (bool) {
        return stakerData[_staker].stakedAmount > 0;
    }

    /**
     * @dev Adds the given staker from the list of stakers.
     * @param _staker The address of the staker to add.
     */
    function _addStaker(address _staker) internal {
        stakerData[_staker].index = stakers.length;
        stakers.push(_staker);
    }

    /**
     * @dev Removes the given staker from the list of stakers, cleaning its stake and reward balance.
     * @param _staker The address of the staker to remove.
     */
    function _removeStaker(address _staker) internal {
        uint256 stakerIndex = stakerData[_staker].index;
        address lastStaker = stakers[stakers.length - 1];
        stakers[stakerIndex] = lastStaker;
        stakers.pop();
        stakerData[lastStaker].index = stakerIndex;
        stakerData[_staker].index = 0;
        stakerData[_staker].stakedAmount = 0;
        stakerData[_staker].rewardAmount = 0;
    }
}