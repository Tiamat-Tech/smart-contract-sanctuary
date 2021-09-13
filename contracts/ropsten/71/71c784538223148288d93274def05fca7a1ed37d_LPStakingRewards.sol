//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {ILPStakingRewards} from "../interfaces/ILPStakingRewards.sol";
import {BaseRewards} from "./BaseRewards.sol";
import {IFlurryStakingRewards} from "../interfaces/IFlurryStakingRewards.sol";

/**
 * @title Rewards for LP Token Stakers
 * @notice This reward scheme enables users to stake (lock) LP tokens
 * from Automated Market Makers (AMM), e.g. Uniswap, Pancakeswap,
 * into this contract to earn FLURRY tokens.
 */
contract LPStakingRewards is ILPStakingRewards, BaseRewards {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev events
    event Staked(address indexed user, address indexed lpToken, uint256 blockNumber, uint256 amount);
    event Withdrawn(address indexed user, address indexed lpToken, uint256 blockNumber, uint256 amount);
    event LPRewardsRateChanged(uint256 blockNumber, uint256 rewardsRate);
    event LPRewardsEndUpdated(address indexed lpToken, uint256 blockNumber, uint256 rewardsEndBlock);
    event LPAdded(address indexed lpToken);

    /// @dev role of Flurry Staking Rewards contract
    bytes32 public constant FLURRY_STAKING_REWARDS_ROLE = keccak256("FLURRY_STAKING_REWARDS_ROLE");

    /// @dev # FLURRY per block as LP staking reward
    uint256 public override rewardsRate;

    /// @dev total allocation points = sum of allocation points in all pools
    uint256 public totalAllocPoint;

    /// @dev list of LP token addresses eligible for rewards
    address[] private poolList;

    /**
     * @notice PoolInfo
     * @param lpToken Address of LP token contract
     * @param totalStakes Total stakes for this pool
     * @param allocPoint How many allocation points assigned to this pool
     * @param lastUpdateBlock Last block number for staking rewards accrual
     * @param rewardPerToken accumulated reward per staked token
     * @param rewardsEndBlock the last block when reward distubution ends
     * @param stakeTokenOne multiplier for one unit of staked Token
     */
    struct PoolInfo {
        IERC20Upgradeable lpToken;
        uint256 totalStakes;
        uint256 allocPoint;
        uint256 lastUpdateBlock;
        uint256 rewardPerToken;
        uint256 rewardsEndBlock;
        uint256 stakeTokenOne;
    }
    mapping(address => PoolInfo) public poolInfo;
    mapping(address => bool) public override isSupported;

    /**
     * @notice UserInfo
     * @param amount number of LP tokens staked by user
     * @param rewardPerTokenPaid amount of reward already paid to staker per token
     * @param reward accumulated FLURRY reward for each user
     */
    struct UserInfo {
        uint256 amount;
        uint256 rewardPerTokenPaid;
        uint256 reward;
    }
    mapping(address => mapping(address => UserInfo)) public userInfo;

    /// @dev order not guaranteed
    mapping(address => address[]) public userPoolRecord;

    IFlurryStakingRewards public override flurryStakingRewards;

    function initialize(address flurryStakingRewardsAddr) public initializer notZeroAddr(flurryStakingRewardsAddr) {
        BaseRewards.__initialize();
        flurryStakingRewards = IFlurryStakingRewards(flurryStakingRewardsAddr);
    }

    function getUserEngagedPool(address user) external view override notZeroAddr(user) returns (address[] memory) {
        return userPoolRecord[user];
    }

    function getPoolList() external view override returns (address[] memory) {
        return poolList;
    }

    function setRewardsRate(uint256 newRewardsRate) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        updateRewardForAll();
        rewardsRate = newRewardsRate;
        emit LPRewardsRateChanged(block.number, rewardsRate);
    }

    function stake(address lpToken, uint256 amount)
        external
        override
        whenNotPaused
        nonReentrant
        notZeroTokenAddr(lpToken)
        isSupportedLP(lpToken)
    {
        address user = _msgSender();
        // check and update
        require(amount > 0, "Staking amount must be positive");
        require(poolInfo[lpToken].lpToken.balanceOf(user) >= amount, "Not Enough balance to stake");
        updateReward(user, lpToken);
        // state change
        userInfo[lpToken][user].amount += amount;
        poolInfo[lpToken].totalStakes += amount;
        // interaction
        poolInfo[lpToken].lpToken.safeTransferFrom(user, address(this), amount);
        emit Staked(_msgSender(), lpToken, block.number, amount);

        for (uint256 i = 0; i < userPoolRecord[user].length; i++) {
            if (userPoolRecord[user][i] == lpToken) return;
        }
        userPoolRecord[user].push(lpToken);
    }

    function updateRewardInternal(address lpToken) internal {
        PoolInfo storage pool = poolInfo[lpToken];
        pool.rewardPerToken = rewardsPerToken(lpToken);
        pool.lastUpdateBlock = block.number;
    }

    function updateReward(address user, address lpToken) internal {
        updateRewardInternal(lpToken);
        if (user != address(0)) {
            userInfo[lpToken][user].reward = _earned(user, lpToken);
            userInfo[lpToken][user].rewardPerTokenPaid = poolInfo[lpToken].rewardPerToken;
        }
    }

    /**
     * @notice Staking rewards are accrued up to this block (put aside in _rewardsPerTokenPaid)
     * @return min(current block #, last reward accrual block #)
     */
    function lastBlockApplicable(address lpToken) internal view returns (uint256) {
        return _lastBlockApplicable(poolInfo[lpToken].rewardsEndBlock);
    }

    function rewardOf(address user, address lpToken)
        external
        view
        override
        notZeroAddr(user)
        notZeroTokenAddr(lpToken)
        returns (uint256)
    {
        return _earned(user, lpToken);
    }

    function totalRewardOf(address user) external view override notZeroAddr(user) returns (uint256 totalReward) {
        totalReward = 0;
        for (uint256 i = 0; i < poolList.length; i++) {
            totalReward += _earned(user, poolList[i]);
        }
    }

    function stakeOf(address user, address lpToken)
        external
        view
        override
        notZeroAddr(user)
        notZeroTokenAddr(lpToken)
        isSupportedLP(lpToken)
        returns (uint256)
    {
        return userInfo[lpToken][user].amount;
    }

    function rewardsPerToken(address lpToken)
        public
        view
        override
        notZeroTokenAddr(lpToken)
        isSupportedLP(lpToken)
        returns (uint256)
    {
        if (poolInfo[lpToken].totalStakes == 0) return poolInfo[lpToken].rewardPerToken;
        return
            rewardPerTokenInternal(
                poolInfo[lpToken].rewardPerToken,
                lastBlockApplicable(lpToken) - poolInfo[lpToken].lastUpdateBlock,
                rewardRatePerTokenInternal(
                    rewardsRate,
                    poolInfo[lpToken].stakeTokenOne,
                    poolInfo[lpToken].allocPoint,
                    poolInfo[lpToken].totalStakes,
                    totalAllocPoint
                )
            );
    }

    function rewardRatePerTokenStaked(address lpToken)
        external
        view
        override
        notZeroTokenAddr(lpToken)
        isSupportedLP(lpToken)
        returns (uint256)
    {
        if (totalAllocPoint == 0) return type(uint256).max;
        PoolInfo storage pool = poolInfo[lpToken];
        if (pool.totalStakes == 0) return type(uint256).max;
        return
            rewardRatePerTokenInternal(
                rewardsRate,
                poolInfo[lpToken].stakeTokenOne,
                pool.allocPoint,
                pool.totalStakes,
                totalAllocPoint
            );
    }

    function _earned(address user, address lpToken) internal view returns (uint256) {
        UserInfo storage _user = userInfo[lpToken][user];
        return
            super._earned(
                _user.amount,
                rewardsPerToken(lpToken) - _user.rewardPerTokenPaid,
                poolInfo[lpToken].stakeTokenOne,
                _user.reward
            );
    }

    /**
     * @dev removes an LP from an array of addresses by linear search (O(n))
     */
    function removeTokenFromRecord(address user, address lpToken) internal {
        for (uint256 i = 0; i < userPoolRecord[user].length; i++) {
            if (userPoolRecord[user][i] == lpToken) {
                // swap the ith item and the last item
                userPoolRecord[user][i] = userPoolRecord[user][userPoolRecord[user].length - 1];
                // pop the last item
                userPoolRecord[user].pop();
                break;
            }
        }
    }

    function withdraw(address lpToken, uint256 amount)
        external
        override
        whenNotPaused
        notZeroTokenAddr(lpToken)
        nonReentrant
    {
        // if user exits LP, remove LP from record
        if (amount == userInfo[lpToken][_msgSender()].amount) removeTokenFromRecord(_msgSender(), lpToken);
        _withdrawUser(_msgSender(), lpToken, amount);
    }

    function exit(address lpToken) external override whenNotPaused notZeroAddr(lpToken) nonReentrant {
        // remove LP from record
        removeTokenFromRecord(_msgSender(), lpToken);
        _withdrawUser(_msgSender(), lpToken, userInfo[lpToken][_msgSender()].amount);
    }

    function exitAll() external whenNotPaused nonReentrant {
        address user = _msgSender();
        for (uint256 i = 0; i < userPoolRecord[user].length; i++) {
            address poolAddr = userPoolRecord[user][i];
            uint256 amount = userInfo[poolAddr][user].amount;
            if (amount > 0) _withdrawUser(user, poolAddr, amount);
        }
        while (userPoolRecord[user].length > 0) userPoolRecord[user].pop();
    }

    /**
     * @dev this function does NOT handle record removal
     */
    function _withdrawUser(
        address user,
        address lpToken,
        uint256 amount
    ) internal isSupportedLP(lpToken) {
        // check and update
        require(userInfo[lpToken][user].amount != 0, "No stakes to withdraw");
        require(userInfo[lpToken][user].amount >= amount, "Exceeds staked amount");
        updateReward(user, lpToken);
        // state change
        userInfo[lpToken][user].amount -= amount;
        poolInfo[lpToken].totalStakes -= amount;
        // interaction
        poolInfo[lpToken].lpToken.safeTransfer(user, amount);
        emit Withdrawn(user, lpToken, block.number, amount);
    }

    function claimRewardInternal(address user, address lpToken) internal isSupportedLP(lpToken) {
        updateReward(user, lpToken);
        if (userInfo[lpToken][user].reward > 0) {
            userInfo[lpToken][user].reward = flurryStakingRewards.grantFlurry(user, userInfo[lpToken][user].reward);
        }
    }

    function claimReward(address onBehalfOf, address lpToken)
        external
        override
        onlyRole(FLURRY_STAKING_REWARDS_ROLE)
        whenNotPaused
        nonReentrant
        notZeroAddr(onBehalfOf)
        notZeroTokenAddr(lpToken)
    {
        claimRewardInternal(onBehalfOf, lpToken);
    }

    function claimReward(address lpToken) external override whenNotPaused notZeroTokenAddr(lpToken) nonReentrant {
        claimRewardInternal(_msgSender(), lpToken);
    }

    function claimAllRewardInternal(address user) internal {
        for (uint256 i = 0; i < poolList.length; i++) {
            claimRewardInternal(user, poolList[i]);
        }
    }

    function claimAllReward(address onBehalfOf)
        external
        override
        onlyRole(FLURRY_STAKING_REWARDS_ROLE)
        whenNotPaused
        nonReentrant
        notZeroAddr(onBehalfOf)
    {
        claimAllRewardInternal(onBehalfOf);
    }

    function claimAllReward() external override whenNotPaused nonReentrant {
        claimAllRewardInternal(_msgSender());
    }

    function addLP(address lpToken, uint256 allocPoint)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        notZeroAddr(lpToken)
        notSupportedLP(lpToken)
    {
        updateRewardForAll();
        totalAllocPoint += allocPoint;
        poolList.push(lpToken);
        poolInfo[lpToken] = PoolInfo({
            lpToken: IERC20Upgradeable(lpToken),
            allocPoint: allocPoint,
            totalStakes: 0,
            lastUpdateBlock: block.number,
            rewardPerToken: 0,
            rewardsEndBlock: 0,
            stakeTokenOne: getTokenOne(lpToken)
        });
        isSupported[lpToken] = true;
        emit LPAdded(lpToken);
    }

    function setLP(address lpToken, uint256 allocPoint)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        notZeroTokenAddr(lpToken)
        isSupportedLP(lpToken)
    {
        updateRewardForAll();
        totalAllocPoint = totalAllocPoint - poolInfo[lpToken].allocPoint + allocPoint;
        poolInfo[lpToken].allocPoint = allocPoint;
    }

    function startRewards(address lpToken, uint256 rewardDuration)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        notZeroAddr(lpToken)
        isSupportedLP(lpToken)
        isValidDuration(rewardDuration)
    {
        PoolInfo storage pool = poolInfo[lpToken];
        require(block.number > pool.rewardsEndBlock, "Previous rewards period must complete before starting a new one");
        updateRewardInternal(lpToken);
        pool.lastUpdateBlock = block.number;
        pool.rewardsEndBlock = block.number + rewardDuration;
        emit LPRewardsEndUpdated(lpToken, block.number, pool.rewardsEndBlock);
    }

    function endRewards(address lpToken)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
        whenNotPaused
        notZeroTokenAddr(lpToken)
        isSupportedLP(lpToken)
    {
        PoolInfo storage pool = poolInfo[lpToken];
        if (pool.rewardsEndBlock > block.number) {
            pool.rewardsEndBlock = block.number;
            emit LPRewardsEndUpdated(lpToken, block.number, pool.rewardsEndBlock);
        }
    }

    function updateRewardForAll() internal {
        for (uint256 i = 0; i < poolList.length; i++) {
            updateRewardInternal(poolList[i]);
        }
    }

    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) {
        require(!isSupported[token], "!safe");
        _sweepERC20Token(token, to);
    }

    modifier isSupportedLP(address lpToken) {
        require(isSupported[lpToken], "LP Token not supported");
        _;
    }

    modifier notSupportedLP(address lpToken) {
        require(!isSupported[lpToken], "LP token already registered");
        _;
    }
}