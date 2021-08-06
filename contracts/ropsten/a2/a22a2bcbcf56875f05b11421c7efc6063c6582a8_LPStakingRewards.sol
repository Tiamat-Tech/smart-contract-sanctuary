//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    AccessControlEnumerableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import {IStakingRewards} from "../interfaces/IStakingRewards.sol";
import {ILPStakingRewards} from "../interfaces/ILPStakingRewards.sol";
import {Reward} from "./Reward.sol";

contract LPStakingRewards is
    ILPStakingRewards,
    Reward,
    Initializable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Events
    event Staked(address indexed user, address indexed lpToken, uint256 blockNumber, uint256 amount);
    event Withdrawn(address indexed user, address indexed lpToken, uint256 blockNumber, uint256 amount);
    event LPStakingRateChanged(uint256 blockNumber, uint256 stakingRate);
    event LPRewardsEndUpdated(address indexed lpToken, uint256 blockNumber, uint256 rewardsEndBlock);
    event LPAdded(address indexed lpToken);

    struct PoolInfo {
        IERC20Upgradeable lpToken; // Address of LP token contract.
        uint256 totalStakes; // Total stakes for this pool
        uint256 allocPoint; // How many allocation points assigned to this pool
        uint256 lastUpdateBlock; // Last block number for staking rewards accrual
        uint256 rewardPerToken; // accumulated reward per staked token
        uint256 rewardsEndBlock; // the last block when reward distubution ends
        uint256 stakeTokenOne; // multiplier for one unit of staked Token
    }

    struct UserInfo {
        uint256 amount; // number of LP tokens staked by user
        uint256 rewardPerTokenPaid; // amount of reward already paid to user per token
        uint256 reward; // accumulated reward for each user
    }

    mapping(address => PoolInfo) public poolInfo;

    // for querying if a LP is supported by Flurry
    mapping(address => bool) public override isSupported;

    address[] private poolList;

    // Info of each user that stakes LP tokens.
    mapping(address => mapping(address => UserInfo)) public userInfo;
    mapping(address => address[]) public userPoolRecord;

    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    /**
     * @notice Staking rate earned per block from total FLURRY available,
     *         to be shared by the staking pools according to allocation points
     */
    uint256 private stakingRate;

    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");

    address public stakingRewardsAddr;

    function initialize(address _stakingRewardsAddr) public initializer {
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        stakingRewardsAddr = _stakingRewardsAddr;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getUserEngagedPool(address user) external view override returns (address[] memory) {
        return userPoolRecord[user];
    }

    function getPoolList() external view override returns (address[] memory) {
        return poolList;
    }

    function setStakingRate(uint256 newStakingRate) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newStakingRate >= 0, "Reward rate must be non-negative");
        updateRewardForAll();
        stakingRate = newStakingRate;
        emit LPStakingRateChanged(block.number, stakingRate);
    }

    function rewardsRate() external view override returns (uint256) {
        return stakingRate;
    }

    function getRewardsEndBlock(address lpToken) external view override returns (uint256) {
        require(isSupported[lpToken], "LP not supported");
        return poolInfo[lpToken].rewardsEndBlock;
    }

    function stake(address lpToken, uint256 amount) external override {
        require(isSupported[lpToken], "LP not supported");
        address user = _msgSender();
        require(amount > 0, "Staking amount must be positive");
        require(poolInfo[lpToken].lpToken.balanceOf(user) >= amount, "Not Enough balance to stake");

        updateReward(user, lpToken);
        userInfo[lpToken][user].amount += amount;
        poolInfo[lpToken].totalStakes += amount;
        poolInfo[lpToken].lpToken.safeTransferFrom(user, address(this), amount);

        emit Staked(_msgSender(), lpToken, block.number, amount);

        for (uint256 i = 0; i < userPoolRecord[user].length; i++) {
            if (userPoolRecord[user][i] == lpToken) {
                return;
            }
        }
        userPoolRecord[user].push(lpToken);
    }

    function updateReward(address user, address lpToken) internal {
        require(isSupported[lpToken], "LP not supported");
        PoolInfo storage pool = poolInfo[lpToken];
        pool.rewardPerToken = rewardsPerToken(lpToken);
        pool.lastUpdateBlock = block.number;
        if (user != address(0)) {
            userInfo[lpToken][user].reward = _earned(user, lpToken);
            userInfo[lpToken][user].rewardPerTokenPaid = pool.rewardPerToken;
        }
    }

    /**
     * @notice Staking rewards are accrued up to this block (put aside in _rewardsPerTokenPaid)
     * @return min(current block #, last reward accrual block #)
     */
    function lastBlockApplicable(address lpToken) internal view returns (uint256) {
        require(isSupported[lpToken], "LP not supported");
        return _lastBlockApplicable(poolInfo[lpToken].rewardsEndBlock);
    }

    function rewardOf(address user, address lpToken) external view override returns (uint256) {
        return _earned(user, lpToken);
    }

    function totalRewardOf(address user) external view override returns (uint256) {
        uint256 totalReward = 0;
        for (uint256 i = 0; i < poolList.length; i++) {
            totalReward += _earned(user, poolList[i]);
        }
        return totalReward;
    }

    function stakeOf(address user, address lpToken) external view override returns (uint256) {
        require(isSupported[lpToken], "LP not supported");
        return userInfo[lpToken][user].amount;
    }

    function rewardsPerToken(address lpToken) public view override returns (uint256) {
        require(isSupported[lpToken], "LP not supported");
        if (poolInfo[lpToken].totalStakes == 0) {
            return poolInfo[lpToken].rewardPerToken;
        }
        return
            rewardPerTokenInternal(
                poolInfo[lpToken].rewardPerToken,
                lastBlockApplicable(lpToken) - poolInfo[lpToken].lastUpdateBlock,
                stakingRate,
                poolInfo[lpToken].stakeTokenOne,
                poolInfo[lpToken].allocPoint,
                poolInfo[lpToken].totalStakes,
                totalAllocPoint
            );
    }

    function rewardRatePerTokenStaked(address lpToken) external view override returns (uint256) {
        if (totalAllocPoint == 0) return type(uint256).max;
        require(isSupported[lpToken], "LP not supported");
        PoolInfo storage pool = poolInfo[lpToken];
        if (pool.totalStakes == 0) return type(uint256).max;
        return (stakingRate * pool.allocPoint) / pool.totalStakes / totalAllocPoint;
    }

    function _earned(address user, address lpToken) internal view returns (uint256) {
        require(isSupported[lpToken], "LP not supported");
        UserInfo storage _user = userInfo[lpToken][user];
        return
            super._earned(
                _user.amount,
                rewardsPerToken(lpToken) - _user.rewardPerTokenPaid,
                poolInfo[lpToken].stakeTokenOne,
                _user.reward
            );
    }

    function withdraw(address lpToken, uint256 amount) external override {
        require(isSupported[lpToken], "LP not supported");
        _withdrawUser(_msgSender(), lpToken, amount);
    }

    function exit(address lpToken) external override {
        address user = _msgSender();
        _withdrawUser(user, lpToken, userInfo[lpToken][user].amount);
    }

    function exitAll() external {
        address user = _msgSender();
        for (uint256 i = 0; i < userPoolRecord[user].length; i++) {
            address poolAddr = userPoolRecord[user][i];
            uint256 amount = userInfo[poolAddr][user].amount;
            if (amount != 0) {
                _withdrawUser(user, poolAddr, amount);
            }
        }
    }

    function _withdrawUser(
        address user,
        address lpToken,
        uint256 amount
    ) internal {
        require(userInfo[lpToken][user].amount != 0, "No stakes to withdraw");
        require(userInfo[lpToken][user].amount >= amount, "Exceeds staked amount");
        updateReward(user, lpToken);
        userInfo[lpToken][user].amount -= amount;
        poolInfo[lpToken].totalStakes -= amount;
        poolInfo[lpToken].lpToken.safeTransfer(user, amount);
        emit Withdrawn(user, lpToken, block.number, amount);
    }

    function claimReward(address user, address lpToken) external override {
        require(isSupported[lpToken], "LP Token not supported");
        address sender = _msgSender();
        require(sender == address(this) || sender == stakingRewardsAddr, "Only RhoTokenRewards or StakingRewards");

        updateReward(user, lpToken);
        if (userInfo[lpToken][user].reward > 0) {
            require(user != address(0), "claim reward on 0 address");
            userInfo[lpToken][user].reward = IStakingRewards(stakingRewardsAddr).claimLPTokenReward(
                user,
                userInfo[lpToken][user].reward
            );
        }
    }

    function claimAllReward(address user) external override {
        address sender = _msgSender();
        require(sender == address(this) || sender == stakingRewardsAddr, "Only RhoTokenRewards or StakingRewards");
        for (uint256 i = 0; i < poolList.length; i++) {
            this.claimReward(user, poolList[i]);
        }
    }

    function claimReward(address lpToken) external override {
        this.claimReward(_msgSender(), lpToken);
    }

    function claimAllReward() external override {
        this.claimAllReward(_msgSender());
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function addLP(address lpToken, uint256 allocPoint) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isSupported[lpToken], "LP token already registered");
        updateRewardForAll();
        totalAllocPoint += allocPoint;
        poolList.push(lpToken);
        uint256 currentBlock = block.number;

        poolInfo[lpToken] = PoolInfo({
            lpToken: IERC20Upgradeable(lpToken),
            allocPoint: allocPoint,
            totalStakes: 0,
            lastUpdateBlock: currentBlock,
            rewardPerToken: 0,
            rewardsEndBlock: 0,
            stakeTokenOne: 10**IERC20MetadataUpgradeable(lpToken).decimals()
        });
        isSupported[lpToken] = true;
        emit LPAdded(lpToken);
    }

    // Update the given pool's allocation point. Can only be called by the owner.
    function setLP(address lpToken, uint256 allocPoint) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        totalAllocPoint = totalAllocPoint - poolInfo[lpToken].allocPoint + allocPoint;
        poolInfo[lpToken].allocPoint = allocPoint;
    }

    function startRewards(address lpToken, uint256 rewardDuration) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolInfo storage pool = poolInfo[lpToken];
        require(block.number > pool.rewardsEndBlock, "Previous rewards period must complete before starting a new one");
        updateReward(address(0), lpToken);

        pool.lastUpdateBlock = block.number;
        pool.rewardsEndBlock = block.number + rewardDuration;
        emit LPRewardsEndUpdated(lpToken, block.number, pool.rewardsEndBlock);
    }

    function endRewards(address lpToken) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolInfo storage pool = poolInfo[lpToken];
        uint256 currentBlock = block.number;
        if (pool.rewardsEndBlock > currentBlock) {
            pool.rewardsEndBlock = currentBlock;
            emit LPRewardsEndUpdated(lpToken, block.number, pool.rewardsEndBlock);
        }
    }

    function updateRewardForAll() internal {
        for (uint256 i = 0; i < poolList.length; i++) {
            updateReward(address(0), poolList[i]);
        }
    }

    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) {
        _sweepERC20Token(token, to);
    }
}