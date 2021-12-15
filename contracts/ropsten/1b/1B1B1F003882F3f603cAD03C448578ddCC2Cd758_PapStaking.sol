// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PAPStaking
 * @author gotbit.io
 */

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import 'hardhat/console.sol';

contract PapStaking is Ownable {
    IERC20 public DFTY;

    uint256 public TIER1_MIN_VALUE;
    uint256 public TIER2_MIN_VALUE;
    uint256 public TIER3_MIN_VALUE;

    uint256 public COOLDOWN_TO_UNSTAKE;
    uint256 public APY;
    // uint256 public YEAR = 360 days; //for mainnet
    uint256 public YEAR = 30 days;


    enum Tier {
        NOTIER,
        TIER3,
        TIER2,
        TIER1
    }

    struct StakeInstance {
        uint256 amount;
        uint256 lastInteracted;
        uint256 lastStaked; //For staking coolDown
        uint256 rewards;
        Tier tier;
    }

    mapping(address => StakeInstance) private stakes;

    event Staked(uint256 indexed timeStamp, uint256 amount, address indexed user);
    event Unstaked(uint256 indexed timeStamp, uint256 amount, address indexed user);
    event RewardsClaimed(uint256 indexed timeStamp, uint256 amount, address indexed user);

    /**
        @dev Creates PapStaking contract
        @param TOKEN_ERC20 address of DFTY token, which user could stake to get Tier and rewards in DFTY
        @param cooldownToUnstake There is cooldown for unstake after user stake tokens. In days
        @param tier3Value value in DFTY tokens, after this user can get Tier 3, or bigger, if less then user will get NOTIER, which doesn't allow to participate in Deftify IDO pools
        @param tier2Value value in DFTY tokens, after this user can get Tier 2, or bigger
        @param tier1Value value in DFTY tokens, after this user can get Tier 1
        @param apy APY in format: x% * 100, only two digits after comma precision for x is allowed! Example: for 20,87% apy is 2087
     */
    constructor(
        address TOKEN_ERC20,
        uint256 cooldownToUnstake,
        uint256 tier3Value,
        uint256 tier2Value,
        uint256 tier1Value,
        uint256 apy
    ) {
        DFTY = IERC20(TOKEN_ERC20);
        require(tier1Value >= tier2Value && tier2Value >= tier3Value, "TierMinValues should be: tier1 >= tier2 >= tier3");
        TIER1_MIN_VALUE = tier1Value;
        TIER2_MIN_VALUE = tier2Value;
        TIER3_MIN_VALUE = tier3Value;

        COOLDOWN_TO_UNSTAKE = cooldownToUnstake;

        APY = apy;

        transferOwnership(msg.sender);
    }

    /**
        @notice Stake DFTY tokens to get Tier and be allowed to participate in Deftify PAP Pools.
        @dev Allows msg.sender to stake DFTY tokens (transfer DFTY from this contract to msg.sender) to get Tier, which allows to participate in Deftify IDO pools. If user stakes amount more than TIERX_MIN_VALUE he gets this TIER;
        @param amount Amount to stake in wei
     */
    function stake(uint256 amount) external {
        require(
            DFTY.balanceOf(msg.sender) >= amount,
            "You don't have enough money to stake"
        );
        require(amount > 0, 'Amount must be grater than zero');

        StakeInstance storage userStake = stakes[msg.sender];
        Tier userTier;

        uint256 pending = getPendingRewards(msg.sender);
        if (pending > 0) {
            userStake.rewards += pending;
            userStake.lastInteracted = block.timestamp;
            require(DFTY.transfer(msg.sender, userStake.rewards), "Transfer DFTY rewards failed!");
            userStake.rewards = 0;
        }

        userStake.lastInteracted = block.timestamp;

        DFTY.transferFrom(msg.sender, address(this), amount);
        if (userStake.amount + amount >= TIER1_MIN_VALUE) {
            userTier = Tier.TIER1;
        } else if (userStake.amount + amount >= TIER2_MIN_VALUE) {
            userTier = Tier.TIER2;
        } else if (userStake.amount + amount >= TIER3_MIN_VALUE) {
            userTier = Tier.TIER3;
        } else userTier = Tier.NOTIER;

        userStake.amount += amount;
        userStake.lastStaked = block.timestamp;
        userStake.tier = userTier;
        emit Staked(block.timestamp, amount, msg.sender);
    }

    /**
        @notice Unstake DFTY tokens
        @dev This function allows user to unstake (transfer DFTY from this contract to msg.sender) amount of DFTY tokens, checks if COOLDOWN_TO_UNSTAKE
        is passed since user last stake (userStake.lastStaked), updates user rewards in DFTY tokens.
        If user unstake DFTY, and if remaining amount of staked tokens will be less than TIER minimal
        amount user's Tier can decrease (Tier1 => Tier2 => Tier3 => NoTier)
        @param amount amount in wei of DFTY tokens to unstake, can't be bigger than userStake.amount
     */
    function unstake(uint256 amount) external {
        require(amount > 0, 'Cannot unstake 0');
        StakeInstance storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, 'Cannot unstake amount more than available');
        require(
            block.timestamp >= userStake.lastStaked + COOLDOWN_TO_UNSTAKE,
            'Cooldown for unstake is not finished yet!'
        ); //for test in seconds now
        Tier userTier;
        uint256 pending = getPendingRewards(msg.sender);
        if (pending > 0) {
            userStake.rewards += pending;
            userStake.lastInteracted = block.timestamp;
            require(DFTY.transfer(msg.sender, userStake.rewards), "Transfer DFTY rewards failed!");
            userStake.rewards = 0;
        }

        userStake.lastInteracted = block.timestamp;

        DFTY.transfer(msg.sender, amount);

        if (userStake.amount - amount >= TIER1_MIN_VALUE) {
            userTier = Tier.TIER1;
        } else if (userStake.amount - amount >= TIER2_MIN_VALUE) {
            userTier = Tier.TIER2;
        } else if (userStake.amount - amount >= TIER3_MIN_VALUE) {
            userTier = Tier.TIER3;
        } else userTier = Tier.NOTIER;
        userStake.amount -= amount;
        userStake.tier = userTier;
        emit Unstaked(block.timestamp, amount, msg.sender);
    }

    /**
        @notice Claim reward in DFTY tokens for participating in staking programm
        @dev Allows user to claim his rewards. Reward = stakes[user].amount + pendingRewards since last time interacted with this contract;
     */
    function claimRewards() external {
        uint256 pending = getPendingRewards(msg.sender);
        uint256 amount = stakes[msg.sender].rewards + pending;
        require(amount > 0, 'Nothing to claim now');
        require(DFTY.transfer(msg.sender, amount), 'ERC20: transfer issue');
        stakes[msg.sender].lastInteracted = block.timestamp;
        stakes[msg.sender].rewards = 0;
        emit RewardsClaimed(block.timestamp, amount, msg.sender);
    }

    /**
        @notice Get full info of user's stake
        @dev Returns a StakeInstance structure
        @param user address of user
        @return StakeInstance structure
     */
    function UserInfo(address user) external view returns (StakeInstance memory) {
        return stakes[user];
    }

    /**
        @notice Get current rewards amount of a user
        @dev This function need for UI, returns current rewards amount of a user at this point in time
        @param user address of a user
        @return uint256 : rewards amount in wei
     */
    function getRewardInfo(address user) external view returns (uint256) {
        uint256 amount = getPendingRewards(user) + stakes[user].rewards;
        return amount;
    }

    /**
        @notice Get pending rewards at this point of time
        @dev Returns rewards of user based on his staked amount, APY and time passed since last time he interacted with a stake: used functions as a claimRewards, stake, unstake;
        @param user address of a user
        @return uint256 user's pending rewards
     */
    function getPendingRewards(address user) internal view returns (uint256) {
        StakeInstance memory userStake = stakes[user];
        uint256 timePassed = block.timestamp - userStake.lastInteracted;
        uint256 pending = (userStake.amount * APY * timePassed) / (1 * YEAR) / 10000;
        return pending;
    }
}