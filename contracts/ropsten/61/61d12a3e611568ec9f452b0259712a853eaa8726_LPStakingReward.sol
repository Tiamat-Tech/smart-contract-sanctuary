//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

import {
    MathUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {
    SafeMathUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {
    SafeERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {
    IERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    AccessControlEnumerableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import {IStakingRewards} from "../interfaces/IStakingRewards.sol";
import {ILPStakingRewards} from "../interfaces/ILPStakingRewards.sol";

contract LPStakingReward is
    ILPStakingRewards,
    Initializable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Events
    event Staked(address indexed user, address indexed lpAddr, uint256 amount);
    event RewardAdded(uint256 reward);
    event RewardsDurationUpdated(uint256 rewardsEndBlock);
    event LPAdded(address indexed lpToken);

    struct PoolInfo {
        IERC20Upgradeable lpToken; // Address of LP token contract.
        uint256 totalStakes;
        uint256 allocPoint; // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastUpdateBlock; // Last block number that SUSHIs distribution occurs.
        uint256 rewardPerToken;
        uint256 rewardsEndBlock;
        uint256 rewardDurationInBlock;
        uint256 stakeTokenOne;
    }

    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardPerTokenPaid;
        uint256 reward;
    }

    address private _rewardsTokenAddress;
    IERC20Upgradeable private _rewardsToken;
    uint256 private _rewardsTokenOne;

    // Info of each pool.
    // PoolInfo[] public poolInfo;

    mapping(address => PoolInfo) public poolInfo;
    address[] private poolList;

    // Info of each user that stakes LP tokens.
    mapping(address => mapping(address => UserInfo)) public userInfo;
    mapping(address => address[]) public userPoolRecord;

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    /**
     * @notice Staking rewards earned per block for the all staking pools
     */
    uint256 private _stakingRate;

    uint256 private constant BLOCK_TIME_MS = uint256(13500);

    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");

    IStakingRewards private _stakingRewards;
    address private _stakingRewardsAddr;

    function initialize(address flurryToken, address stakingRewards)
        public
        initializer
    {
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        _rewardsTokenAddress = flurryToken;
        _rewardsToken = IERC20Upgradeable(_rewardsTokenAddress);
        _rewardsTokenOne =
            10**IERC20MetadataUpgradeable(_rewardsTokenAddress).decimals();

        _stakingRewardsAddr = stakingRewards;
        _stakingRewards = IStakingRewards(stakingRewards);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getUserEngagedPool(address user)external view returns(address[] memory){
        return userPoolRecord[user];
    }

    function getPoolList()external view returns(address[] memory){
        return poolList;
    }

    function setStakingRate(uint256 stakingRate)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _stakingRate = stakingRate;
    }

    function getStakingRate() external view returns (uint256) {
        return _stakingRate;
    }

    function stake(address lpAddr, uint256 amount) external override {
        address user = _msgSender();
        require(amount > 0, "Cannot stake 0 tokens");
        require(
            poolInfo[lpAddr].lpToken.balanceOf(user) >= amount,
            "Not Enough balance to stake"
        );
        updateReward(user, lpAddr);
        userInfo[lpAddr][user].amount = userInfo[lpAddr][user].amount.add(
            amount
        );
        poolInfo[lpAddr].totalStakes = poolInfo[lpAddr].totalStakes.add(amount);
        poolInfo[lpAddr].lpToken.safeTransferFrom(user, address(this), amount);

        emit Staked(_msgSender(), lpAddr, amount);

        for (uint256 i = 0; i < userPoolRecord[user].length; i++) {
            if (userPoolRecord[user][i] == lpAddr) {
                return;
            }
        }
        userPoolRecord[user].push(lpAddr);
    }

    function updateReward(address user, address lpAddr) internal {
        PoolInfo storage pool = poolInfo[lpAddr];
        pool.rewardPerToken = rewardsPerToken(lpAddr);
        pool.lastUpdateBlock = block.number;
        if (user != address(0)) {
            userInfo[lpAddr][user].reward = _earned(user, lpAddr);
            userInfo[lpAddr][user].rewardPerTokenPaid = pool.rewardPerToken;
        }
    }

    /**
     * @notice Staking rewards are accrued up to this block (put aside in _rewardsPerTokenPaid)
     * @return min(The current block # or last rewards accrual block #)
     */
    function lastBlockApplicable(address lpAddr)
        internal
        view
        returns (uint256)
    {
        return
            MathUpgradeable.min(block.number, poolInfo[lpAddr].rewardsEndBlock);
    }

    /**
     * @return The amount of staking rewards distrubuted per block
     */
    function rewardsRate() external view override returns (uint256) {
        return _stakingRate;
    }

    function rewardOf(address user, address lpAddr)
        external
        view
        override
        returns (uint256)
    {
        return _earned(user, lpAddr);
    }

    function stakeOf(address user, address lpAddr)
        external
        view
        override
        returns (uint256)
    {
        return userInfo[lpAddr][user].amount;
    }

    /**
     * @notice Total accumulated reward per token
     * @return Reward entitlement per token staked (in wei)
     */
    function rewardsPerToken(address lpAddr)
        public
        view
        override
        returns (uint256)
    {
        if (poolInfo[lpAddr].totalStakes == 0) {
            return poolInfo[lpAddr].rewardPerToken;
        }
        return
            poolInfo[lpAddr].rewardPerToken.add(
                (
                    lastBlockApplicable(lpAddr).sub(
                        poolInfo[lpAddr].lastUpdateBlock
                    )
                )
                    .mul(_stakingRate)
                    .mul(poolInfo[lpAddr].stakeTokenOne)
                    .mul(poolInfo[lpAddr].allocPoint)
                    .div(poolInfo[lpAddr].totalStakes)
                    .div(totalAllocPoint)
            );
    }

    function _earned(address user, address lpAddr)
        internal
        view
        returns (uint256)
    {
        UserInfo memory _user = userInfo[lpAddr][user];
        return
            _user
                .amount
                .mul(rewardsPerToken(lpAddr).sub(_user.rewardPerTokenPaid))
                .div(poolInfo[lpAddr].stakeTokenOne)
                .add(_user.reward);
    }

    function withdraw(address lpAddr, uint256 amount) external override {
        _withdrawUser(_msgSender(), lpAddr, amount);
    }

    function exit(address lpAddr) external override {
        address user = _msgSender();
        _withdrawUser(user, lpAddr, userInfo[lpAddr][user].amount);
    }

    function exitAll() external {
        address user = _msgSender();
        for (uint256 i = 0;i<userPoolRecord[user].length;i++){
            address poolAddr = userPoolRecord[user][i];
            uint256 amount = userInfo[poolAddr][user].amount;
            if (amount!=0){
                _withdrawUser(user, poolAddr, amount);
            }
        }
    }

    function _withdrawUser(
        address user,
        address lpAddr,
        uint256 amount
    ) internal {
        require(userInfo[lpAddr][user].amount != 0, "No stakes to withdraw");
        require(
            userInfo[lpAddr][user].amount >= amount,
            "Exceeds staked amount"
        );
        updateReward(user, lpAddr);
        userInfo[lpAddr][user].amount = userInfo[lpAddr][user].amount.sub(
            amount
        );
        poolInfo[lpAddr].totalStakes = poolInfo[lpAddr].totalStakes.sub(amount);
        poolInfo[lpAddr].lpToken.safeTransfer(user, amount);
    }

    function claimReward(address lpAddr) external override {
        address user = _msgSender();
        updateReward(user, lpAddr);
        if (userInfo[lpAddr][user].reward > 0) {
            userInfo[lpAddr][user].reward = _stakingRewards.claimLPReward(
                user,
                userInfo[lpAddr][user].reward
            );
        }
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        address _lpToken,
        uint256 rewardsEndBlock
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        totalAllocPoint = totalAllocPoint.add(_allocPoint);

        uint256 _rewardDurationInBlock = rewardsEndBlock - block.number;
        uint256 _stakeTokenOne =
            10**IERC20MetadataUpgradeable(_lpToken).decimals();

        poolList.push(_lpToken);
        poolInfo[_lpToken] = PoolInfo({
            lpToken: IERC20Upgradeable(_lpToken),
            allocPoint: _allocPoint,
            totalStakes: 0,
            lastUpdateBlock: block.number,
            rewardPerToken: 0,
            rewardsEndBlock: rewardsEndBlock,
            rewardDurationInBlock: _rewardDurationInBlock,
            stakeTokenOne: _stakeTokenOne
        });

        emit LPAdded(_lpToken);
    }

    // Update the given pool's allocation point. Can only be called by the owner.
    function set(address lpAddr, uint256 _allocPoint)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[lpAddr].allocPoint).add(
            _allocPoint
        );
        poolInfo[lpAddr].allocPoint = _allocPoint;
    }

    function setRewardsDuration(
        address lpAddr,
        uint256 rewardsDurationInSeconds
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolInfo storage pool = poolInfo[lpAddr];
        require(
            block.number > pool.rewardsEndBlock,
            "Previous rewards period must be completed before changing the duration for the new period"
        );

        pool.rewardDurationInBlock = rewardsDurationInSeconds.mul(1e3).div(
            BLOCK_TIME_MS
        );
        pool.rewardsEndBlock = block.number.add(pool.rewardDurationInBlock);
        emit RewardsDurationUpdated(pool.rewardsEndBlock);
    }

    function getRewardForDuration(address lpAddr)
        external
        view
        override
        returns (uint256)
    {
        return _stakingRate.mul(poolInfo[lpAddr].rewardDurationInBlock);
    }

    function shortenRewardsDuration(address lpAddr)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        PoolInfo storage pool = poolInfo[lpAddr];
        if (pool.rewardsEndBlock > block.number) {
            pool.rewardsEndBlock = block.number;
            emit RewardsDurationUpdated(block.number);
        }
    }

    function sweepERC20Token(address token, address to)
        external
        onlyRole(SWEEPER_ROLE)
    {
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }
}