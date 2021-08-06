//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {
    IERC20MetadataUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    AccessControlEnumerableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import {IRhoTokenRewards} from "../interfaces/IRhoTokenRewards.sol";
import {IStakingRewards} from "../interfaces/IStakingRewards.sol";
import {Reward} from "./Reward.sol";

/**
 * @title Rewards for RhoToken holders
 * @notice Users do not need to deposit rho Tokens into this contract
 * Instead, rho token holders are entitled to bonus rewards tokens by simply holding Rho Tokens
 */
contract RhoTokenRewards is
    IRhoTokenRewards,
    Reward,
    Initializable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    // Events
    event RewardRateChanged(uint256 blockNumber, uint256 rewardRate);
    event RewardsEndUpdated(address indexed rhoTokenAddr, uint256 blockNumber, uint256 rewardsEndBlock);
    event RhoTokenAdded(address indexed rhoTokenAddr);

    // Note: total supply is queried from the corresponding rhoToken contract. Not stored as a state here
    struct RhoTokenInfo {
        IERC20Upgradeable rhoToken; // reference to underlying RhoToken
        uint256 allocPoint; // allocation points (weight) assigned to this rhoToken
        uint256 rewardPerToken; // accumulated reward per RhoToken
        uint256 lastUpdateBlock; // block number that reward was last accrued at
        uint256 rewardEndBlock; // the last block when reward distubution ends
        uint256 rhoTokenOne; // multiplier for one unit of RhoToken
    }

    struct UserInfo {
        uint256 rewardPerTokenPaid; // amount of reward already paid to user per token
        uint256 reward; // accumulated reward for each user
    }

    mapping(address => RhoTokenInfo) public rhoTokenInfo;
    address[] private rhoTokenList;

    // for querying if a rhoToken is supported for rewards
    mapping(address => bool) public override isSupported;

    // Info of each user that holds rhoToken
    mapping(address => mapping(address => UserInfo)) public userInfo;

    /**
     * @notice The accumulated rewards for each address holder.
     */
    mapping(address => uint256) public rewards;

    // Total allocation points. Must be the sum of all allocation points in all rhoTokens.
    uint256 public totalAllocPoint;

    /**
     * @notice Rewards to be earned per block for the entire pool of RhoToken holders
     */
    uint256 public override rewardRate;

    /**
     * @notice reference to Staking Rewards contract
     * which controls all FLURRY staking rewards
     */
    IStakingRewards public flurryRewards;

    /**
     * @notice address of staking rewards contract
     */
    address public stakingRewardsAddress;

    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");

    function initialize(address stakingRewards) public initializer {
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        stakingRewardsAddress = stakingRewards;
        flurryRewards = IStakingRewards(stakingRewards);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getRhoTokenList() external view override returns (address[] memory) {
        return rhoTokenList;
    }

    function setRewardRate(uint256 newRewardRate) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        updateRewardForAll();
        rewardRate = newRewardRate;
        emit RewardRateChanged(block.number, rewardRate);
    }

    function rewardOf(address user, address rhoToken) external view override returns (uint256) {
        require(isSupported[rhoToken], "RhoToken not supported");
        return _earned(user, rhoToken);
    }

    function totalRewardOf(address user) external view override returns (uint256) {
        uint256 totalReward = 0;
        for (uint256 i = 0; i < rhoTokenList.length; i++) {
            totalReward += _earned(user, rhoTokenList[i]);
        }
        return totalReward;
    }

    function rewardsPerToken(address rhoToken) public view override returns (uint256) {
        require(isSupported[rhoToken], "RhoToken not supported");

        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        uint256 totalSupply = _rhoToken.rhoToken.totalSupply();
        if (totalSupply == 0) {
            return _rhoToken.rewardPerToken;
        }
        return
            rewardPerTokenInternal(
                _rhoToken.rewardPerToken,
                lastBlockApplicable(rhoToken) - _rhoToken.lastUpdateBlock,
                rewardRate,
                _rhoToken.rhoTokenOne,
                _rhoToken.allocPoint,
                totalSupply,
                totalAllocPoint
            );
    }

    function rewardRatePerRhoToken(address rhoToken) external view override returns (uint256) {
        if (totalAllocPoint == 0) return type(uint256).max;
        require(isSupported[rhoToken], "RhoToken not supported");
        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        uint256 totalSupply = _rhoToken.rhoToken.totalSupply();
        if (totalSupply == 0) return type(uint256).max;
        return (rewardRate * _rhoToken.allocPoint) / _rhoToken.rhoToken.totalSupply() / totalAllocPoint;
    }

    function lastBlockApplicable(address rhoToken) internal view returns (uint256) {
        require(isSupported[rhoToken], "RhoToken not supported");
        return _lastBlockApplicable(rhoTokenInfo[rhoToken].rewardEndBlock);
    }

    function _earned(address user, address rhoToken) internal view returns (uint256) {
        UserInfo storage _user = userInfo[rhoToken][user];
        return
            super._earned(
                IERC20Upgradeable(rhoToken).balanceOf(user),
                rewardsPerToken(rhoToken) - _user.rewardPerTokenPaid,
                rhoTokenInfo[rhoToken].rhoTokenOne,
                _user.reward
            );
    }

    function updateReward(address user, address rhoToken) public override {
        require(isSupported[rhoToken], "RhoToken not supported");

        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        _rhoToken.rewardPerToken = rewardsPerToken(rhoToken);
        _rhoToken.lastUpdateBlock = lastBlockApplicable(rhoToken);

        if (user != address(0)) {
            userInfo[rhoToken][user].reward = _earned(user, rhoToken);
            userInfo[rhoToken][user].rewardPerTokenPaid = _rhoToken.rewardPerToken;
        }
    }

    function updateRewardForAll() internal {
        for (uint256 i = 0; i < rhoTokenList.length; i++) {
            this.updateReward(address(0), rhoTokenList[i]);
        }
    }

    function startRewards(address rhoToken, uint256 rewardDuration) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isSupported[rhoToken], "RhoToken not supported");
        require(rewardDuration > 0, "Reward duration cannot be zero");
        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        require(
            block.number > _rhoToken.rewardEndBlock,
            "Previous rewards period must complete before starting a new one"
        );
        updateReward(address(0), rhoToken);
        _rhoToken.lastUpdateBlock = block.number;
        _rhoToken.rewardEndBlock = block.number + rewardDuration;
        emit RewardsEndUpdated(rhoToken, block.number, _rhoToken.rewardEndBlock);
    }

    function getRewardsEndBlock(address rhoToken) external view override returns (uint256) {
        require(isSupported[rhoToken], "RhoToken not supported");
        return rhoTokenInfo[rhoToken].rewardEndBlock;
    }

    function endRewards(address rhoToken) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isSupported[rhoToken], "RhoToken not supported");

        RhoTokenInfo storage _rhoToken = rhoTokenInfo[rhoToken];
        uint256 currentBlock = block.number;
        if (_rhoToken.rewardEndBlock > currentBlock) {
            _rhoToken.rewardEndBlock = currentBlock;
            emit RewardsEndUpdated(rhoToken, currentBlock, currentBlock);
        }
    }

    function claimReward(address rhoToken) external override {
        require(isSupported[rhoToken], "RhoToken not supported");
        this.claimReward(_msgSender(), rhoToken);
    }

    function claimReward(address user, address rhoToken) external override {
        require(isSupported[rhoToken], "RhoToken not supported");

        address sender = _msgSender();
        require(sender == address(this) || sender == stakingRewardsAddress, "Only RhoTokenRewards or StakingRewards");
        updateReward(user, rhoToken);
        UserInfo storage _user = userInfo[rhoToken][user];
        if (_user.reward > 0) {
            _user.reward = flurryRewards.claimRhoTokenReward(user, _user.reward);
        }
    }

    function claimAllReward() external override {
        this.claimAllReward(_msgSender());
    }

    function claimAllReward(address user) external override {
        address sender = _msgSender();
        require(sender == address(this) || sender == stakingRewardsAddress, "Only RhoTokenRewards or StakingRewards");
        for (uint256 i = 0; i < rhoTokenList.length; i++) {
            this.claimReward(user, rhoTokenList[i]);
        }
    }

    // Add a new rhoToken to the list. Can only be called by the owner.
    function addRhoToken(address rhoToken, uint256 allocPoint) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!isSupported[rhoToken], "RhoToken already registered");
        updateRewardForAll();
        totalAllocPoint += allocPoint;
        rhoTokenList.push(rhoToken);
        uint256 currentBlock = block.number;

        rhoTokenInfo[rhoToken] = RhoTokenInfo({
            rhoToken: IERC20Upgradeable(rhoToken),
            allocPoint: allocPoint,
            lastUpdateBlock: currentBlock,
            rewardPerToken: 0,
            rewardEndBlock: 0,
            rhoTokenOne: 10**IERC20MetadataUpgradeable(rhoToken).decimals()
        });
        isSupported[rhoToken] = true;
        emit RhoTokenAdded(rhoToken);
    }

    // Update the given rhoToken's allocation point. Can only be called by the owner.
    function setRhoToken(address rhoToken, uint256 allocPoint) public override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isSupported[rhoToken], "RhoToken not supported");

        updateRewardForAll();
        totalAllocPoint = totalAllocPoint - rhoTokenInfo[rhoToken].allocPoint + allocPoint;
        rhoTokenInfo[rhoToken].allocPoint = allocPoint;
    }

    function sweepERC20Token(address token, address to) external override onlyRole(SWEEPER_ROLE) {
        _sweepERC20Token(token, to);
    }
}