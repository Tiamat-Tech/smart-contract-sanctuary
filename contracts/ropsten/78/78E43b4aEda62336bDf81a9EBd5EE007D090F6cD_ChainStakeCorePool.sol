// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./ChainStakePoolBase.sol";

/**
 * @title ChainStake Core Pool
 *
 * @notice Core pools represent permanent pools like RewardToken or RewardToken/ETH Pair pool,
 *      core pools allow staking for arbitrary periods of time up to 1 year
 *
 * @dev See ChainStakePoolBase for more details
 */
contract ChainStakeCorePool is ChainStakePoolBase {
    using SafeMath for uint256;

    /// @dev Flag indicating pool type, false means "core pool"
    bool public constant override isFlashPool = false;

    /// @dev Pool tokens value available in the pool;
    ///      pool token examples are RewardToken (RewardToken core pool) or RewardToken/ETH pair (LP core pool)
    /// @dev For LP core pool this value doesnt' count for RewardToken tokens received as Vault rewards
    ///      while for RewardToken core pool it does count for such tokens as well
    uint256 public poolTokenReserve;

    /**
     * @dev Creates/deploys an instance of the core pool
     *
     * @param _rewardToken RewardToken ERC20 Token ChainStakeERC20 address
     * @param _factory Pool factory ChainStakePoolFactory instance/address
     * @param _poolToken token the pool operates on, for example RewardToken or RewardToken/ETH pair
     * @param _initBlock initial block used to calculate the rewards
     * @param _weight number representing a weight of the pool, actual weight fraction
     *      is calculated as that number divided by the total pools weight and doesn't exceed one
     */

    constructor(
        address _rewardToken,
        ChainStakePoolFactory _factory,
        address _poolToken,
        uint256 _initBlock,
        uint256 _weight
    )
        ChainStakePoolBase(
            _rewardToken,
            _factory,
            _poolToken,
            _initBlock,
            _weight
        )
    {}

    /**
     * @notice Service function to calculate and pay pending vault and yield rewards to the sender
     *
     * @dev Internally executes similar function `_processRewards` from the parent smart contract
     *      to calculate and pay yield rewards; adds vault rewards processing
     *
     * @dev Can be executed by anyone at any time, but has an effect only when
     *      executed by deposit holder and when at least one block passes from the
     *      previous reward processing
     * @dev Executed internally when "staking as a pool" (`stakeAsPool`)
     * @dev When timing conditions are not met (executed too frequently, or after factory
     *      end block), function doesn't throw and exits silently
     */

    function processRewards(uint256 _amount) external override {
        _processRewards(msg.sender, true, false, _amount);
    }

    /**
     * @inheritdoc ChainStakePoolBase
     *
     * @dev Additionally to the parent smart contract, updates vault rewards of the holder,
     *      and updates (increases) pool token reserve (pool tokens value available in the pool)
     */
    function _stake(
        address _staker,
        uint256 _amount,
        uint256 _lockedUntil,
        bool _isYield
    ) internal override {
        super._stake(_staker, _amount, _lockedUntil, _isYield);
        poolTokenReserve = poolTokenReserve.add(_amount);
        // increase totalstakedcount when user stake token .
        factory.increaseStakedCount();
    }

    /**
     * @inheritdoc ChainStakePoolBase
     *
     * @dev Additionally to the parent smart contract, updates vault rewards of the holder,
     *      and updates (decreases) pool token reserve (pool tokens value available in the pool)
     */
    function _unstake(
        address _staker,
        uint256 _depositId,
        uint256 _amount
    ) internal override {
        User storage user = users[_staker];
        Deposit memory stakeDeposit = user.deposits[_depositId];

        //check if blocknumber is greater than endBlock, then bypass locking period and unstake the amount
        if (factory.endBlock() > blockNumber()) {
            require(
                stakeDeposit.lockedFrom == 0 ||
                    now256() > stakeDeposit.lockedUntil,
                "deposit not yet unlocked"
            );
        }
        poolTokenReserve = poolTokenReserve.sub(_amount);
        super._unstake(_staker, _depositId, _amount);
    }

    /**
     * @inheritdoc ChainStakePoolBase
     *
     * @dev Additionally to the parent smart contract, processes vault rewards of the holder,
     *      and for RewardToken pool updates (increases) pool token reserve (pool tokens value available in the pool)
     */
    function _processRewards(
        address _staker,
        bool _withUpdate,
        bool _isStake,
        uint256 _amount
    ) internal override returns (uint256 pendingYield) {
        pendingYield = super._processRewards(
            _staker,
            _withUpdate,
            _isStake,
            _amount
        );

        // update `poolTokenReserve` only if this is a RewardToken Core Pool
        if (poolToken == rewardToken) {
            poolTokenReserve = poolTokenReserve.add(pendingYield);
        }
    }
}