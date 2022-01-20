//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

// Inheritance
import "./interfaces/OnDemandToken.sol";
import "./StakingRewards.sol";

contract StakingRewardsV2 is StakingRewards {
    using SafeMath for uint256;

    constructor(
        address _owner,
        address _rewardsDistribution,
        address _stakingToken,
        address _rewardsToken
    ) StakingRewards(_owner, _rewardsDistribution, _stakingToken, _rewardsToken) {}

    // ========== RESTRICTED FUNCTIONS ========== //

    /// @dev when notifying about amount, we don't have to mint or send any tokens, reward tokens will be mint on demand
    ///         this method is used to restart staking
    function notifyRewardAmount(
        uint256 _reward
    ) override external whenActive onlyRewardsDistribution updateReward(address(0)) {
        uint256 _rewardsDuration = rewardsDuration;

        if (block.timestamp >= periodFinish) {
            rewardRate = _reward / _rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = _reward.add(leftover) / _rewardsDuration;
        }

        require(rewardRate != 0, "invalid rewardRate");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + _rewardsDuration;
        emit RewardAdded(_reward);
    }

    // when farming was started with 1y and 12tokens
    // and we want to finish after 4 months, we need to end up with situation
    // like we were starting with 4mo and 4 tokens.
    function finishFarming() override external whenActive onlyOwner {
        require(block.timestamp < periodFinish, "can't stop if not started or already finished");

        stopped = true;

        if (totalSupply() != 0) {
            uint256 remaining = periodFinish.sub(block.timestamp);
            rewardsDuration -=  remaining;
        }

        periodFinish = block.timestamp;

        emit FarmingFinished(0);
    }

    function version() external pure override returns (uint256) {
        return 2;
    }

    function getReward() override public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];

        if (reward != 0) {
            rewards[msg.sender] = 0;
            OnDemandToken(address(rewardsToken)).mint(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }
}