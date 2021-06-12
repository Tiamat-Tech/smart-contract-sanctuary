//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IRhoTokenRewards} from "../interfaces/IRhoTokenRewards.sol";
import {IStakingRewards} from "../interfaces/IStakingRewards.sol";


/**
 * @title Rewards for RhoToken holders
 * @notice Users do not need to deposit rho Tokens into this contract
 * Instead, rho token holders are entitled to bonus rewards tokens by simply holding Rho Tokens
 */
contract RhoTokenRewards is IRhoTokenRewards, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    // Events
    event RewardAdded(uint256 reward);
    event RewardEarned(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 durationInBlocks);
    event RewardsEndUpdated(uint256 rewardsEndBlock);


    /**
     * @notice address of rewards token contract
     */
    address public rewardsTokenAddress;

    /**
     * @notice address of rho token contract
     */
    address public rhoTokenAddress;

    /**
     * @notice address of staking rewards contract
     */
    address public stakingRewardsAddress;

    /**
     * @notice reference to rewards token
     */
    IERC20Upgradeable private _rewardsToken;

    /**
     * @notice reference to underlying RhoToken
     */
    IERC20Upgradeable private _rhoToken;

    /**
     * @notice multiplier for one unit of RhoToken
     */
    uint256 private _rhoTokenOne;

    /**
     * @notice reference to Staking Rewards contract
     * which controls all FLURRY staking rewards
     */
    IStakingRewards private _flurryRewards;

    /**
     * @notice Average block time in milleseconds. Assume 13.25 seconds per block
     * It is safer to use block time when estimating time passed, as opposed to block.timestamp, which
     * is considered to be not reliable and vulnerable to attacks
     * Assume 13.25 seconds per block
     */
    uint256 private constant BLOCK_TIME_MS = uint256(13250);

    /**
     * @notice The accumulated rewards for each address holder.
     */
    mapping(address => uint256) public rewards;

    /**
     * @notice Amount of rewards already paid to address holder per token
     */
    mapping(address => uint256) public rewardsPerTokenPaid;

    /**
     * @notice Rewards to be earned per block for the entire pool of RhoToken holders
     */
    uint256 public rewardsRate;

    /**
     * @notice Block number that staking reward was last accrued at
     */
    uint256 public lastUpdateBlock;

    /**
     * @notice rewards entitlement per RhoToken held
     */
    uint256 public rewardsPerTokenStored;

    /**
     * @notice Duration of the current rewards period in blocks
     */
    uint256 public rewardsDurationInBlocks;

    /**
     * @notice The last block when rewards distubution end
     */
    uint256 public rewardsEndBlock;


    function initialize(address rhoToken, address rewardToken, address stakingRewards) public initializer {
        OwnableUpgradeable.__Ownable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        rhoTokenAddress = rhoToken;
        rewardsTokenAddress = rewardToken;
        stakingRewardsAddress = stakingRewards;

        _rhoToken = IERC20Upgradeable(rhoToken);
        _rhoTokenOne = 10**IERC20MetadataUpgradeable(rhoToken).decimals();
        _rewardsToken = IERC20Upgradeable(rewardToken);
        _flurryRewards = IStakingRewards(stakingRewards);
    }

    /**
     * @notice A method to allow a stakeholder to check his rewards.
     * @param addr The stakeholder to check rewards for.
     */
    function rewardOf(address addr) external view override returns (uint256) {
        return _earned(addr);
    }

    /**
     * @notice Total accumulated reward per token
     * @return Reward entitlement for rho token
     */
    function rewardsPerToken() public view override returns (uint256) {
        uint256 totalSupply = _rhoToken.totalSupply();
        if (totalSupply == 0) {
            return rewardsPerTokenStored;
        }
        return rewardsPerTokenStored.add(
            (lastBlockApplicable().sub(lastUpdateBlock)).mul(rewardsRate).mul(_rhoTokenOne).div(totalSupply)
        );
    }

    /**
     * @return min(The current block # or last rewards accrual block #)
     */
    function lastBlockApplicable() internal view returns (uint256) {
        return MathUpgradeable.min(block.number, rewardsEndBlock);
    }

    /**
     * @param addr Address of rhoToken holder
     * @return Total rewards earned for addr holder
     */
    function _earned(address addr) internal view returns (uint256) {
        return _rhoToken.balanceOf(addr).mul(rewardsPerToken().sub(rewardsPerTokenPaid[addr])).div(_rhoTokenOne).add(rewards[addr]);
    }

    /**
     * @notice Calculate and allocate rewards token for address holder
     * Rewards should accrue from lastUpdateBlock to lastBlockApplicable
     */
    function updateReward(address addr) public override {
        rewardsPerTokenStored = rewardsPerToken();
        lastUpdateBlock = lastBlockApplicable();
        if (addr != address(0)) {
            rewards[addr] = _earned(addr);
            rewardsPerTokenPaid[addr] = rewardsPerTokenStored;
            emit RewardEarned(addr, rewards[addr]);
        }
    }

    /**
     * @notice Admin function - A method to set reward amount
     */
    function setRewardAmount(uint256 reward) external override onlyOwner {
        updateReward(address(0));
        require(rewardsDurationInBlocks > 0, "Rewards duration is 0");
        if (block.number >= rewardsEndBlock) {
            rewardsRate = reward.div(rewardsDurationInBlocks);
        } else {
            uint256 blocksRemaining = rewardsEndBlock.sub(block.number);
            uint256 leftover = blocksRemaining.mul(rewardsRate);
            rewardsRate = reward.add(leftover).div(rewardsDurationInBlocks);
        }

        // Reward amount cannot be more than the balance of rewardsToken contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = _rewardsToken.balanceOf(stakingRewardsAddress);
        require(rewardsRate <= balance.div(rewardsDurationInBlocks), "Insufficient balance for rewards");

        lastUpdateBlock = block.number;
        rewardsEndBlock = block.number.add(rewardsDurationInBlocks);
        emit RewardAdded(reward);
        emit RewardsEndUpdated(rewardsEndBlock);
    }

    /**
     * @notice Admin function A method to set reward duration
     * @param rewardsDurationInSeconds Reward Duration in seconds
     */
    function setRewardsDuration(uint256 rewardsDurationInSeconds) external override onlyOwner {
        require(
            block.number > rewardsEndBlock,
            "Previous rewards period must be completed before changing the duration for the new period"
        );
        rewardsDurationInBlocks = rewardsDurationInSeconds.mul(1e3).div(BLOCK_TIME_MS);
        emit RewardsDurationUpdated(rewardsDurationInBlocks);
    }

    /**
     * @notice Admin function - End Rewards distribution earlier, if there is one running
     */
    function shortenRewardsDuration() external override onlyOwner {
        if (rewardsEndBlock > block.number) {
            rewardsEndBlock = block.number;
            emit RewardsEndUpdated(rewardsEndBlock);
        }
    }

    /**
     * @notice A method to allow a rhoToken holder to claim his rewards.
     * Note: If stakingRewards contract do not have enough tokens to pay,
     * this will fail silently and user rewards remains as a credit in this contract
     */
    function claimReward() external override {
        address user = _msgSender();
        updateReward(user);
        if (rewards[user] > 0) {
            rewards[user] = _flurryRewards.claimRhoTokenReward(user, rewards[user]);
        }
    }

    function sweepERC20Token(address token, address to)external override onlyOwner{
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }

}