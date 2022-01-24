//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

// Inheritance
import "./interfaces/OnDemandToken.sol";
import "./StakingRewardsMigratable.sol";

/// @author  umb.network
/// @dev V2 minting rewards on demand, so no need to mint tokens beforehand,
///         just execute `notifyRewardAmount(amount)` and that is it.
contract StakingRewardsV2 is StakingRewardsMigratable {
    using SafeMath for uint256;

    constructor(
        address _owner,
        address _rewardsDistribution,
        address _stakingToken,
        address _rewardsToken
    ) StakingRewardsMigratable(_owner, _rewardsDistribution, _stakingToken, _rewardsToken) {}

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

    /// @param _user address
    /// @param _recipient address, where to send reward
    function _getReward(address _user, address _recipient)
        override
        internal
        nonReentrant
        updateReward(_user)
        returns (uint256 reward)
    {
        reward = rewards[_user];

        if (reward != 0) {
            rewards[_user] = 0;
            OnDemandToken(address(rewardsToken)).mint(_recipient, reward);
            emit RewardPaid(_user, reward);
        }
    }
}