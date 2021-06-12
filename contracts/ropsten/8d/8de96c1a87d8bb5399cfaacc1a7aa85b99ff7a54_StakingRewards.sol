// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import {SafeMathUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {IStakingRewards} from "../interfaces/IStakingRewards.sol";

contract StakingRewards is
    IStakingRewards,
    Initializable,
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Events
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardEarned(address indexed user, uint256 reward);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 durationInBlocks);
    event RewardsEndUpdated(uint256 rewardsEndBlock);
    event NotEnoughBalance(address indexed user, uint256 withdrawalAmount);

    // FLURRY Token Staking
    // Locking FLURRY tokens to earn more FLURRY tokens
    // subject to the stakingYield set by the Flurry token owner.
    // rewardsToken is assumed to be a ERC20 compliant token with 18 decimals
    address public _rewardsTokenAddress;
    IERC20Upgradeable private _rewardsToken;
    uint256 private _rewardsTokenOne;

    // TODO - 3. Pool Token Staking
    // When users stake eligible pool tokens e.g. a LP token from uniswap on a trading pair that involves a rho token
    // to earn extra flurry tokens.

    /**
     * @notice Average block time in milleseconds. Assume 13.25 seconds per block
     * It is safer to use block time when estimating time passed, as opposed to block.timestamp, which
     * is considered to be not reliable and vulnerable to attacks
     * Assume 13.25 seconds per block
     */
    uint256 private constant BLOCK_TIME_MS = uint256(13250);

    /**
     * @notice We usually require to know who are all the stakeholders.
     */
    address[] private _stakeholders;

    /**
     * @notice  The stakes for each stakeholder.
     * stake holder address -> flurry tokens staked
     */
    uint256 private _totalStakes;

    /**
     * @notice  The stakes for each stakeholder.
     * stake holder address -> flurry tokens staked
     */
    mapping(address => uint256) private _stakes;

    /**
     * @notice The accumulated rewards for each stakeholder.
     * stake holder address -> rewards allocated to staker denominated in flurry token
     */
    mapping(address => uint256) public rewards;

    /**
     * @notice Amount of rewards already paid to stakeholder per token
     */
    mapping(address => uint256) public rewardsPerTokenPaid;

    /**
     * @notice Staking rewards earned per block for the entire staking pool
     */
    uint256 public stakingRate;

    /**
     * @notice Block number that staking reward was last accrued at
     */
    uint256 public lastUpdateBlock;

    /**
     * @notice Staking Rewards entitlement per staking token held
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

    bytes32 public constant RHO_TOKEN_REWARDS_ROLE =
        keccak256("RHO_TOKEN_REWARDS_ROLE");

    // Role
    bytes32 public constant SWEEPER_ROLE = keccak256("SWEEPER_ROLE");
    bytes32 public constant LP_TOKEN_REWARDS_ROLE =
        keccak256("LP_TOKEN_REWARDS_ROLE");

    /**
     * @notice initialize function is used in place of constructor for upgradeability
     * Have to call initializers in the parent classes to proper initialize
     */
    function initialize(address flurryToken) public initializer {
        AccessControlEnumerableUpgradeable.__AccessControlEnumerable_init();
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        _rewardsTokenAddress = flurryToken;
        _rewardsToken = IERC20Upgradeable(_rewardsTokenAddress);
        _rewardsTokenOne =
            10**IERC20MetadataUpgradeable(_rewardsTokenAddress).decimals();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice A method to the aggregated stakes from all stakeholders.
     * @return uint256 The aggregated stakes from all stakeholders.
     */
    function totalStakes() external view override returns (uint256) {
        return _totalStakes;
    }

    /**
     * @notice A method to retrieve the stake for a stakeholder.
     * @param addr The stakeholder to retrieve the stake for.
     * @return uint256 The amount of wei staked.
     */
    function stakeOf(address addr) external view override returns (uint256) {
        return _stakes[addr];
    }

    /**
     * @notice A method to allow a stakeholder to check his rewards.
     * @param addr The stakeholder to check rewards for.
     * @return Total rewards allocated to stakeholder.
     */
    function rewardOf(address addr) external view override returns (uint256) {
        return _earned(addr);
    }

    /**
     * @notice Staking rewards are accrued up to this block (put aside in rewardsPerTokenPaid)
     * @return min(The current block # or last rewards accrual block #)
     */
    function lastBlockApplicable() internal view returns (uint256) {
        return MathUpgradeable.min(block.number, rewardsEndBlock);
    }

    /**
     * @return The amount of staking rewards distrubuted per block
     */
    function rewardsRate() external view override returns (uint256) {
        return stakingRate;
    }

    /**
     * @notice Total accumulated reward per token
     * @return Reward entitlement per token staked (in wei)
     */
    function rewardsPerToken() public view override returns (uint256) {
        if (_totalStakes == 0) {
            return rewardsPerTokenStored;
        }
        return
            rewardsPerTokenStored.add(
                (lastBlockApplicable().sub(lastUpdateBlock))
                    .mul(stakingRate)
                    .mul(_rewardsTokenOne)
                    .div(_totalStakes)
            );

    }

    /**
     * @notice Calculate and allocate rewards token for stake holder
     * Staking rewards should be calculated from lastUpdateBlock to lastBlockApplicable
     */
    function updateReward(address addr) internal {
        rewardsPerTokenStored = rewardsPerToken();
        lastUpdateBlock = lastBlockApplicable();
        if (addr != address(0)) {
            rewards[addr] = _earned(addr);
            rewardsPerTokenPaid[addr] = rewardsPerTokenStored;
            emit RewardEarned(addr, rewards[addr]);
        }
    }

    function _earned(address addr) internal view returns (uint256) {
        return
            _stakes[addr]
                .mul(rewardsPerToken().sub(rewardsPerTokenPaid[addr]))
                .div(_rewardsTokenOne)
                .add(rewards[addr]);
    }

    /**
     * @notice A method to allow a stakeholder to check his rewards.
     * @return Reward entitlement for token staked
     */
    function getRewardForDuration() external view override returns (uint256) {
        return stakingRate.mul(rewardsDurationInBlocks);
    }

    /**
     * @notice A method to set reward amount
     * Can only called by Owner
     */
    function setRewardAmount(uint256 reward)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        updateReward(address(0));
        require(rewardsDurationInBlocks > 0, "Rewards duration is 0");

        if (block.number >= rewardsEndBlock) {
            stakingRate = reward.div(rewardsDurationInBlocks);
        } else {
            uint256 blocksRemaining = rewardsEndBlock.sub(block.number);
            uint256 leftover = blocksRemaining.mul(stakingRate);
            stakingRate = reward.add(leftover).div(rewardsDurationInBlocks);
        }

        // Reward amount cannot be more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = _rewardsToken.balanceOf(address(this));
        require(
            stakingRate <= balance.div(rewardsDurationInBlocks),
            "Insufficient balance for rewards"
        );

        lastUpdateBlock = block.number;
        rewardsEndBlock = block.number.add(rewardsDurationInBlocks);
        emit RewardAdded(reward);
        emit RewardsEndUpdated(rewardsEndBlock);
    }

    /**
     * @notice A method to set reward duration
     * Can only called by Owner
     */
    function setRewardsDuration(uint256 _rewardsDurationInSeconds)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            block.number > rewardsEndBlock,
            "Previous rewards period must be completed before changing the duration for the new period"
        );
        rewardsDurationInBlocks = _rewardsDurationInSeconds.mul(1e3).div(BLOCK_TIME_MS);
        emit RewardsDurationUpdated(rewardsDurationInBlocks);
    }

    /**
     * @notice Admin function - End Rewards distribution earlier, if there is one running
     */
    function shortenRewardsDuration() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (rewardsEndBlock > block.number) {
            rewardsEndBlock = block.number;
            emit RewardsEndUpdated(rewardsEndBlock);
        }
    }

    /**
     * @notice A method to add a stake.
     * @param amount amount of flurry tokens to be staked
     */
    function stake(uint256 amount) external override nonReentrant {
        address user = _msgSender();
        require(amount > 0, "Cannot stake 0 tokens");
        require(
            _rewardsToken.balanceOf(user) >= amount,
            "Not Enough balance to stake"
        );
        updateReward(user);
        _stakes[user] = _stakes[user].add(amount);
        _totalStakes = _totalStakes.add(amount);
        _rewardsToken.safeTransferFrom(user, address(this), amount);
        emit Staked(user, amount);
    }

    /**
     * @notice A method to add rewards that are not staked to the staking pool
     * @param amount amount of flurry tokens to be staked
     */
    function stakeRewards(uint256 amount) external override {
        //TODO -asdas
    }

    /**
     * @notice A method to remove a stake.
     * @param amount amount of staked tokens to remove from staking
     */
    function withdraw(uint256 amount) external override {
        _withdrawUser(_msgSender(), amount);
    }

    /**
     * @notice A method to remove a stake.
     * @param user address of stakeholder
     * @param amount amount of staked tokens to remove from staking
     */
    function _withdrawUser(address user, uint256 amount) internal nonReentrant {
        require(isStakeholder(user), "No stakes to withdraw");
        require(_stakes[user] >= amount, "Exceeds staked amount");
        updateReward(user);
        _stakes[user] = _stakes[user].sub(amount);
        _totalStakes = _totalStakes.sub(amount);
        _rewardsToken.safeTransfer(user, amount);
        emit Withdrawn(user, amount);
    }

    /**
     * @notice A method to allow a stakeholder to withdraw full stake.
     * Rewards are not automatically claimed. Use claimReward()
     */
    function exit() external override {
        address user = _msgSender();
        if (isStakeholder(user)) {
            _withdrawUser(user, _stakes[user]);
        }
    }

    /**
     * @notice A method to allow a stakeholder to withdraw his rewards.
     */
    function claimReward() external override nonReentrant {
        address user = _msgSender();
        updateReward(user);
        if (rewards[user] > 0) {
            rewards[user] = grantFlurryInternal(user, rewards[user]);
        }
    }

    /**
     * @notice used to RhoTokenRewards contract for rewards distribution
     * @param addr account address of RhoToken holder
     * @param amount amount of flurry token reward to claim
     * @return returns outstanding amount if claim is not successful
     */
    function claimRhoTokenReward(address addr, uint256 amount)
        external
        override
        onlyRole(RHO_TOKEN_REWARDS_ROLE)
        returns (uint256)
    {
        require(addr != address(0), "claim reward on 0 address");
        return grantFlurryInternal(addr, amount);
    }

    function claimLPReward(address addr, uint256 amount)
        external
        override
        onlyRole(LP_TOKEN_REWARDS_ROLE)
        returns (uint256)
    {
        require(addr != address(0), "claim reward on 0 address");
        return grantFlurryInternal(addr, amount);
    }

    /**
     * @notice total balance held under staking rewards contract
     **/
    function totalRewardsPool() external view returns (uint256) {
        return _rewardsToken.balanceOf(address(this));
    }

    /**
     * @notice Transfer FLURRY to the user
     * @dev Note: If there is not enough FLURRY, we do not perform the transfer call
     * @param user The address of the user to transfer FLURRY to
     * @param amount The amount of FLURRY to transfer
     * @return The amount of FLURRY which was NOT transferred to the user
     */
    function grantFlurryInternal(address user, uint256 amount)
        internal
        returns (uint256)
    {
        uint256 flurryRemaining = _rewardsToken.balanceOf(address(this));
        if (amount > 0 && amount <= flurryRemaining) {
            _rewardsToken.safeTransfer(user, amount);
            emit RewardPaid(user, amount);
            return 0;
        }
        emit NotEnoughBalance(user, amount);
        return amount;
    }

    /**
     * @notice A method to check if an address is a stakeholder.
     * @param addr The address to verify.
     * @return bool Whether the address is a stakeholder
     */
    function isStakeholder(address addr) public view returns (bool) {
        return _stakes[addr] > 0;
    }

    function sweepERC20Token(address token, address to)
        external
        override
        onlyRole(SWEEPER_ROLE)
    {
        require(token != address(_rewardsToken), "!safe");
        IERC20Upgradeable tokenToSweep = IERC20Upgradeable(token);
        tokenToSweep.transfer(to, tokenToSweep.balanceOf(address(this)));
    }
}