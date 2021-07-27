// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
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
import {Reward} from "./Reward.sol";
import {IRhoTokenRewards} from "../interfaces/IRhoTokenRewards.sol";
import {ILPStakingRewards} from "../interfaces/ILPStakingRewards.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

contract StakingRewards is
    IStakingRewards,
    Reward,
    Initializable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    uint256 private constant MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    // Events
    event StakingRateChanged(uint256 blockNumber, uint256 stakingRate);
    event RewardsEndUpdated(uint256 blockNumber, uint256 rewardsEndBlock);
    event Staked(address indexed user, uint256 blockNumber, uint256 amount);
    event Withdrawn(address indexed user, uint256 blockNumber, uint256 amount);

    // FLURRY Token Staking
    // Locking FLURRY tokens to earn more FLURRY tokens
    // subject to the stakingYield set by the Flurry token owner.
    // rewardsToken is assumed to be a ERC20 compliant token with 18 decimals
    IERC20Upgradeable public rewardsToken;

    uint256 public rewardsTokenOne;

    address[] private _stakeholders;

    /**
     * @notice Staking rewards earned per block for the entire staking pool
     */
    uint256 private _stakingRate;

    /**
     * @notice The total staked amount of FLURRY tokens
     */
    uint256 public override totalStakes;

    struct UserInfo {
        uint256 stake; // FLURRY stakes for each staker
        uint256 rewardPerTokenPaid; // amount of reward already paid to staker per token
        uint256 reward; // accumulated FLURRY reward
    }

    /**
     * @notice 1 level less than userInfo in LP and rhoToken Rewards
     */
    mapping(address => UserInfo) public userInfo;

    /**
     * @notice block number that staking reward was last accrued at
     */
    uint256 public lastUpdateBlock;

    /**
     * @notice staking reward entitlement per FLURRY staked
     */
    uint256 public rewardsPerTokenStored;

    /**
     * @notice The last block when rewards distubution end
     */
    uint256 public rewardsEndBlock;

    /**
     * @notice last block of time lock
     */
    uint256 public lockEndBlock;

    /**
     * @notice reference to LP Staking Rewards contract
     */
    ILPStakingRewards public lpStakingRewards;

    /**
     * @notice reference to RhoToken Rewards contract
     */
    IRhoTokenRewards public rhoTokenRewards;

    // Role
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");
    bytes32 public constant LP_TOKEN_REWARDS_ROLE = keccak256("LP_TOKEN_REWARDS_ROLE");
    bytes32 public constant RHO_TOKEN_REWARDS_ROLE = keccak256("RHO_TOKEN_REWARDS_ROLE");

    /**
     * @notice initialize function is used in place of constructor for upgradeability
     * Have to call initializers in the parent classes to proper initialize
     */
    function initialize(address _flurryTokenAddr) public initializer {
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        rewardsToken = IERC20Upgradeable(_flurryTokenAddr);
        rewardsTokenOne = 10**IERC20MetadataUpgradeable(_flurryTokenAddr).decimals();
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function stakeOf(address user) external view override returns (uint256) {
        return userInfo[user].stake;
    }

    function rewardOf(address user) external view override returns (uint256) {
        return _earned(user);
    }

    function lastBlockApplicable() internal view returns (uint256) {
        return _lastBlockApplicable(rewardsEndBlock);
    }

    function rewardsRate() external view override returns (uint256) {
        return _stakingRate;
    }

    function rewardsPerToken() public view override returns (uint256) {
        if (totalStakes == 0) {
            return rewardsPerTokenStored;
        } else {
            return
                rewardsPerTokenStored.add(
                    ((lastBlockApplicable() - lastUpdateBlock) * _stakingRate * rewardsTokenOne) / totalStakes
                );
        }
    }

    function rewardRatePerTokenStaked() external view override returns (uint256) {
        if (totalStakes == 0) {
            return MAX_UINT256;
        } else {
            return (_stakingRate * rewardsTokenOne) / totalStakes;
        }
    }

    function updateReward(address addr) internal {
        rewardsPerTokenStored = rewardsPerToken();
        lastUpdateBlock = lastBlockApplicable();
        if (addr != address(0)) {
            userInfo[addr].reward = _earned(addr);
            userInfo[addr].rewardPerTokenPaid = rewardsPerTokenStored;
        }
    }

    function _earned(address addr) internal view returns (uint256) {
        return
            super._earned(
                userInfo[addr].stake,
                rewardsPerToken() - userInfo[addr].rewardPerTokenPaid,
                rewardsTokenOne,
                userInfo[addr].reward
            );
    }

    function setStakingRate(uint256 stakingRate) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        updateReward(address(0));
        _stakingRate = stakingRate;
        emit StakingRateChanged(block.number, _stakingRate);
    }

    function startRewards(uint256 rewardsDuration) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(block.number > rewardsEndBlock, "Previous rewards period must complete before starting a new one");
        updateReward(address(0));
        lastUpdateBlock = block.number;
        rewardsEndBlock = block.number + rewardsDuration;
        emit RewardsEndUpdated(block.number, rewardsEndBlock);
    }

    function endRewards() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (rewardsEndBlock > block.number) {
            rewardsEndBlock = block.number;
            emit RewardsEndUpdated(block.number, rewardsEndBlock);
        }
    }

    function isLocked() external view override returns (bool) {
        return block.number <= lockEndBlock;
    }

    function setTimeLock(uint256 lockDuration) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        lockEndBlock = block.number + lockDuration;
    }

    function earlyUnlock() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        lockEndBlock = block.number;
    }

    function stake(uint256 amount) external override nonReentrant {
        address user = _msgSender();
        require(amount > 0, "Cannot stake 0 tokens");
        require(rewardsToken.balanceOf(user) >= amount, "Not Enough balance to stake");
        updateReward(user);
        totalStakes += amount;
        userInfo[user].stake += amount;
        rewardsToken.safeTransferFrom(user, address(this), amount);
        emit Staked(user, block.number, amount);
    }

    function withdraw(uint256 amount) external override {
        _withdrawUser(_msgSender(), amount);
    }

    function _withdrawUser(address user, uint256 amount) internal nonReentrant {
        require(isStakeholder(user), "No stakes to withdraw");
        require(userInfo[user].stake >= amount, "Exceeds staked amount");
        updateReward(user);
        userInfo[user].stake -= amount;
        totalStakes -= amount;
        rewardsToken.safeTransfer(user, amount);
        emit Withdrawn(user, block.number, amount);
    }

    function exit() external override {
        address user = _msgSender();
        if (isStakeholder(user)) {
            _withdrawUser(user, userInfo[user].stake);
        }
    }

    function claimReward() external override {
        require(
            block.number > lockEndBlock,
            string(abi.encodePacked("Reward locked until block ", StringsUpgradeable.toString(lockEndBlock)))
        );
        claimReward(_msgSender());
    }

    function claimAllRewards() external override {
        require(
            block.number > lockEndBlock,
            string(abi.encodePacked("Reward locked until block ", StringsUpgradeable.toString(lockEndBlock)))
        );
        claimAllRewards(_msgSender());
    }

    function claimReward(address user) internal {
        updateReward(user);
        if (userInfo[user].reward > 0) {
            userInfo[user].reward = grantFlurryInternal(user, userInfo[user].reward);
        }
    }

    function claimAllRewards(address user) internal {
        lpStakingRewards.claimAllReward(user);
        rhoTokenRewards.claimAllReward(user);
        claimReward(user);
    }

    function claimRhoTokenReward(address addr, uint256 amount)
        external
        override
        onlyRole(RHO_TOKEN_REWARDS_ROLE)
        returns (uint256)
    {
        require(addr != address(0), "claim reward on 0 address");
        require(
            block.number > lockEndBlock,
            string(abi.encodePacked("Reward locked until block ", StringsUpgradeable.toString(lockEndBlock)))
        );
        return grantFlurryInternal(addr, amount);
    }

    function claimLPTokenReward(address addr, uint256 amount)
        external
        override
        onlyRole(LP_TOKEN_REWARDS_ROLE)
        returns (uint256)
    {
        require(addr != address(0), "claim reward on 0 address");
        require(
            block.number > lockEndBlock,
            string(abi.encodePacked("Reward locked until block ", StringsUpgradeable.toString(lockEndBlock)))
        );
        return grantFlurryInternal(addr, amount);
    }

    function totalRewardsPool() external view returns (uint256) {
        return rewardsToken.balanceOf(address(this));
    }

    function grantFlurryInternal(address user, uint256 amount) internal nonReentrant returns (uint256) {
        uint256 flurryRemaining = rewardsToken.balanceOf(address(this));
        if (amount > 0 && amount <= flurryRemaining) {
            rewardsToken.safeTransfer(user, amount);
            emit RewardPaid(user, amount);
            return 0;
        }
        emit NotEnoughBalance(user, amount);
        return amount;
    }

    function isStakeholder(address addr) public view returns (bool) {
        return userInfo[addr].stake > 0;
    }

    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) {
        require(token != address(rewardsToken), "!safe");
        _sweepERC20Token(token, to);
    }

    function totalRewardsOf(address user) external view override returns (uint256) {
        return lpStakingRewards.totalRewardOf(user) + rhoTokenRewards.totalRewardOf(user) + this.rewardOf(user);
    }

    function setRhoTokenRewardContract(address _rhoTokenRewardAddr) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        rhoTokenRewards = IRhoTokenRewards(_rhoTokenRewardAddr);
    }

    function setLPRewardsContract(address lpRewardsAddr) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        lpStakingRewards = ILPStakingRewards(lpRewardsAddr);
    }
}