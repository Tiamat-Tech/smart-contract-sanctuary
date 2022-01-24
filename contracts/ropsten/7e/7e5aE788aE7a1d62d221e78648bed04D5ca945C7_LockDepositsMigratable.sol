//SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./MigrationPoolsV8.sol";
import "./LockDepositsBatches.sol";

/// @author  umb.network
contract LockDepositsMigratable is MigrationPoolsV8, LockDepositsBatches {
    event StakedTokenMigrated();
    event RewardTokenMigrated();

    constructor(address _rewardToken) LockDepositsBatches (_rewardToken) {}

    function migrateReward(address[] calldata _tokens, MigrationPoolsV8 _newPool, bytes calldata _data) external {
        unchecked {
            uint256 amount;

            for (uint256 i; i < _tokens.length; i++) {
                uint256 count = depositNextIndex[msg.sender][_tokens[i]];

                for (uint256 x; x < count; x++) {
                    amount += _claimFor(msg.sender, _tokens[i], x, address(this));
                }
            }

            if (amount == 0) return;

            emit RewardTokenMigrated();
            if (!rewardToken.transfer(address(_newPool), amount)) revert TokenTransferFailed();

            _newPool.migrateTokenCallback(address(rewardToken), msg.sender, amount, _data);
        }
    }

    function migrateLockedTokens(
        address[] calldata _tokens,
        MigrationPoolsV8[] calldata _newPools,
        bytes[] calldata _data
    ) external {
        for (uint256 i; i < _tokens.length; i++) {
            uint256 count = depositNextIndex[msg.sender][_tokens[i]];
            uint256 amount;

            for (uint256 x; x < count; x++) {
                amount += _withdrawFor(msg.sender, _tokens[i], x, address(0));
            }

            if (amount == 0) continue;

            emit StakedTokenMigrated();
            if (!Token(_tokens[i]).transfer(address(_newPools[i]), amount)) revert TokenTransferFailed();

            _newPools[i].migrateTokenCallback(_tokens[i], msg.sender, amount, _data[i]);
        }
    }

    function migrateTokenCallback(address _token, address _user, uint256 _amount, bytes calldata _data)
        external
        override
        onlyPool
    {
        uint32 period = abi.decode(_data, (uint32));
        _lock(_user, _token, period, _amount, true);
    }
}