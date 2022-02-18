//SPDX-License-Identifier: MIT
pragma solidity 0.7.5;
pragma abicoder v2;

import "./StakingRewardsV2.sol";

/// @author  umb.network
/// @notice Math is based on synthetix staking contract
///         Contract allows to stake and lock tokens. For rUMB tokens only locking option is available.
///         When locking user choose period and based on period multiplier is apply to the amount (boost).
///         If pool is set for rUMB1->rUMB2, (rUmbPool) then rUMB2 can be locked as well
contract StakingLens {
    struct LockData {
        uint256 period;
        uint256 multiplier;
    }

    /// @notice returns array of max 100 booleans, where index corresponds to lock id. `true` means lock can be withdraw
    function getVestedLockIds(StakingRewardsV2 _pool, address _account, uint256 _offset)
        external
        view
        returns (bool[] memory results)
    {
        (,,,,uint256 nextLockIndex) = _pool.balances(_account);
        uint256 batch = 100;

        if (nextLockIndex == 0) return results;
        if (nextLockIndex <= _offset) return results;

        uint256 end = _offset + batch > nextLockIndex ? nextLockIndex : _offset + batch;

        results = new bool[](end);

        for (uint256 i = _offset; i < end; i++) {
            (,, uint32 unlockDate,, uint32 withdrawnAt) = _pool.locks(_account, i);
            results[i] = withdrawnAt == 0 && block.timestamp < unlockDate;
        }
    }

    /// @notice returns array of max 100 booleans, where index corresponds to lock id.
    ///         `true` means lock was not withdrawn yet
    function getActiveLockIds(StakingRewardsV2 _pool, address _account, uint256 _offset)
        external
        view
        returns (bool[] memory results)
    {
        (,,,,uint256 nextLockIndex) = _pool.balances(_account);
        uint256 batch = 100;

        if (nextLockIndex == 0) return results;
        if (nextLockIndex <= _offset) return results;

        uint256 end = _offset + batch > nextLockIndex ? nextLockIndex : _offset + batch;

        results = new bool[](end);

        for (uint256 i = _offset; i < end; i++) {
            (,,,, uint32 withdrawnAt) = _pool.locks(_account, i);
            results[i] = withdrawnAt == 0;
        }
    }

    function getPeriods(StakingRewardsV2 _pool) external view returns (uint256[] memory periods) {
        return _pool.getPeriods();
    }

    function getPeriodsAndMultipliers(StakingRewardsV2 _pool) external view returns (LockData[] memory lockData) {
        uint256[] memory periods = _pool.getPeriods();
        uint256 n = periods.length;
        lockData = new LockData[](n);

        for (uint256 i; i < n; i++) {
            lockData[i] = LockData(periods[i], _pool.multipliers(periods[i]));
        }
    }
}