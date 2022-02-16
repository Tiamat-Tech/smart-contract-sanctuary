//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import "./interfaces/MigratablePool.sol";
import "./StakingLockable.sol";

/// @author  umb.network
contract StakingRewardsV2 is MigratablePool, StakingLockable {
    event StakedTokenMigrated();
    event RewardTokenMigrated();

    constructor(
        address _owner,
        address _rewardsDistribution,
        address _stakingToken,
        address _rewardsToken,
        bool _rUmbPool
    ) StakingLockable(_owner, _rewardsDistribution, _stakingToken, _rewardsToken, _rUmbPool) {}

    /// @param _newPool address of new pool, where tokens will be staked
    /// @param _withdrawAmount amount to withdraw, if > 0 then staked tokens will be withdrawn
    /// @param _data additional data for new pool
    function migrateRewardToken(
        MigratablePool _newPool,
        uint256 _withdrawAmount,
        bytes calldata _data
    ) external {
        emit RewardTokenMigrated();

        if (_withdrawAmount != 0) _withdraw(_withdrawAmount, msg.sender, msg.sender);

        uint256 reward = _getReward(msg.sender, address(_newPool));
        _newPool.migrateTokenCallback(address(rewardsToken), msg.sender, reward, _data);
    }

    /// @param _newPool address of new pool, where tokens will be staked
    /// @param _amount amount of staked tokens to migrate to new pool
    /// @param _getUserReward if true, reward tokens will be claimed
    /// @param _data additional data for new pool
    function migrateStakingToken(
        MigratablePool _newPool,
        uint256 _amount,
        bool _getUserReward,
        bytes calldata _data
    ) external {
        emit StakedTokenMigrated();

        _withdraw(_amount, msg.sender, address(_newPool));
        _newPool.migrateTokenCallback(address(stakingToken), msg.sender, _amount, _data);

        if (_getUserReward) _getReward(msg.sender, msg.sender);
    }

    function migrateTokenCallback(address _token, address _user, uint256 _amount, bytes calldata _data)
        external
        override
        onlyPool
    {
        uint32 period = abi.decode(_data, (uint32));
        if (period == 0 && rUmbPool) revert("you can only lock rUMB tokens");

        if (period == 0) {
            _stake(_token, _user, _amount, 0, true);
        } else {
            _lockTokens(_user, _token, _amount, period);
        }
    }
}