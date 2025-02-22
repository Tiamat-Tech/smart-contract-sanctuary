// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "synthetix/contracts/interfaces/IStakingRewards.sol";

import "./RewardDistributionRecipient.sol";

/**
  @title Farming pool inherited from Synthetix
  @notice This contract is used to reward `rewardToken` when `stakeToken` is staked.
  forked from https://github.com/FloatProtocol/float-staking/blob/main/contracts/staking/Phase2Pool.sol
 */
contract FarmingPool is IStakingRewards, Context, AccessControl, RewardDistributionRecipient, ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /* ========== CONSTANTS ========== */
  uint256 public constant DURATION = 30 days;
  bytes32 public constant RECOVER_ROLE = keccak256("RECOVER_ROLE");

  /* ========== STATE VARIABLES ========== */
  IERC20 public rewardToken;
  IERC20 public stakeToken;

  address public feeCollector;

  uint256 public depositFeeBps = 0;
  uint256 public withdrawalFeeBps = 0;
  uint256 public periodFinish = 0;
  uint256 public rewardRate = 0;
  uint256 public claimDelay = 0;
  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;

  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;
  mapping(address => uint256) public lastDepositTime;

  uint256 private _totalSupply;
  mapping(address => uint256) private _balances;

  /* ========== CONSTRUCTOR ========== */

  /**
    @notice Construct a new FarmingPool
    @param _admin The default role controller for 
    @param _rewardDistribution The reward distributor (can change reward rate)
    @param _rewardToken The reward token to distribute
    @param _stakingToken The staking token used to qualify for rewards
   */
  constructor(
    address _admin,
    address _rewardDistribution,
    address _rewardToken,
    address _stakingToken,
    address _feeCollector
  ) RewardDistributionRecipient(_admin) {
    rewardDistribution = _rewardDistribution;
    feeCollector = _feeCollector;
    rewardToken = IERC20(_rewardToken);
    stakeToken = IERC20(_stakingToken);
    
    _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    _setupRole(RECOVER_ROLE, _admin);
  }

  /* ========== EVENTS ========== */

  event RewardAdded(uint256 reward);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);
  event Recovered(address token, uint256 amount);

  /* ========== MODIFIERS ========== */

  modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = lastTimeRewardApplicable();
    if (account != address(0)) {
      rewards[account] = earned(account);
      userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
  }

  /* ========== VIEWS ========== */

  function totalSupply() public override(IStakingRewards) view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public override(IStakingRewards) view returns (uint256) {
    return _balances[account];
  }

  function lastTimeRewardApplicable() public override(IStakingRewards) view returns (uint256) {
    return Math.min(block.timestamp, periodFinish);
  }

  function rewardPerToken() public override(IStakingRewards) view returns (uint256) {
    if (totalSupply() == 0) {
      return rewardPerTokenStored;
    }

    return
      rewardPerTokenStored.add(
        lastTimeRewardApplicable()
          .sub(lastUpdateTime)
          .mul(rewardRate)
          .mul(1e18)
          .div(totalSupply())
      );
  }

  function earned(address account) public override(IStakingRewards) view returns (uint256) {
    return
      balanceOf(account)
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
  }

  function nextClaimTime(address account) public view returns (uint256) {
    return lastDepositTime[account].add(claimDelay);
  }

  function canClaimReward(address account) public view returns (bool) {
    return block.timestamp.sub(lastDepositTime[account]) > claimDelay;
  }

  function getRewardForDuration() external override(IStakingRewards) view returns (uint256) {
    return rewardRate.mul(DURATION);
  }

  /* ========== MUTATIVE FUNCTIONS ========== */
  function stake(uint256 amount) public virtual override(IStakingRewards) updateReward(msg.sender) {
    require(amount > 0, "FarmingPool::stake: Cannot stake 0");

    if (feeCollector != address(0) && depositFeeBps > 0) {
      uint256 fee = amount.mul(depositFeeBps).div(10000);
      amount = amount.sub(fee);
      stakeToken.safeTransfer(feeCollector, fee);
    }

    _totalSupply = _totalSupply.add(amount);
    _balances[msg.sender] = _balances[msg.sender].add(amount);

    stakeToken.safeTransferFrom(msg.sender, address(this), amount);
    lastDepositTime[msg.sender] = block.timestamp;
    emit Staked(msg.sender, amount);
  }

  function withdraw(uint256 amount) public override(IStakingRewards) updateReward(msg.sender) {
    require(amount > 0, "FarmingPool::withdraw: Cannot withdraw 0");
    _totalSupply = _totalSupply.sub(amount);
    _balances[msg.sender] = _balances[msg.sender].sub(amount);

    if (feeCollector != address(0) && withdrawalFeeBps > 0) {
      uint256 fee = amount.mul(withdrawalFeeBps).div(10000);
      // deduct the fee
      amount = amount.sub(fee);
      stakeToken.safeTransfer(feeCollector, fee);
    }
    stakeToken.safeTransfer(msg.sender, amount);
    emit Withdrawn(msg.sender, amount);
  }

  function exit() external override(IStakingRewards) {
    withdraw(balanceOf(msg.sender));
    if (canClaimReward(msg.sender)) {
      getReward();
    }
  }

  function getReward() public virtual override(IStakingRewards) updateReward(msg.sender) {
    uint256 reward = earned(msg.sender);
    if (reward > 0) {
      require(canClaimReward(msg.sender), "cannot claim rewards");
      rewards[msg.sender] = 0;
      rewardToken.safeTransfer(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  /* ========== RESTRICTED FUNCTIONS ========== */

  /* ----- Reward Distributor ----- */

  /**
    @notice Should be called after the amount of reward tokens has
     been sent to the contract.
     Reward should be divisible by duration.
    @param reward number of tokens to be distributed over the duration.
   */
  function notifyRewardAmount(uint256 reward)
    external
    override
    onlyRewardDistribution
    updateReward(address(0))
  {
    if (block.timestamp >= periodFinish) {
      rewardRate = reward.div(DURATION);
    } else {
      uint256 remaining = periodFinish.sub(block.timestamp);
      uint256 leftover = remaining.mul(rewardRate);
      rewardRate = reward.add(leftover).div(DURATION);
    }

    // Ensure provided reward amount is not more than the balance in the contract.
    // Keeps reward rate within the right range to prevent overflows in earned or rewardsPerToken
    // Reward + leftover < 1e18
    uint256 balance = rewardToken.balanceOf(address(this));
    require(
      rewardRate <= balance.div(DURATION), 
      "FarmingPool::notifyRewardAmount: Insufficent balance for reward rate"
    );

    lastUpdateTime = block.timestamp;
    periodFinish = block.timestamp.add(DURATION);
    emit RewardAdded(reward);
  }

  function setFeeBps(uint256 _deposit, uint256 _withdraw) external onlyRewardDistribution {
    require(_deposit < 5000 && _withdraw < 5000, "wut?");
    depositFeeBps = _deposit;
    withdrawalFeeBps = _withdraw;
  }

  function setFeeCollector(address _collector) external onlyRewardDistribution {
    feeCollector = _collector;
  }

  function setClaimDelay(uint _delay) external onlyRewardDistribution {
    claimDelay = _delay;
  }
  
  /* ----- RECOVER_ROLE ----- */

  /**
    @notice Provide accidental token retrieval. 
    @dev Sourced from synthetix/contracts/StakingRewards.sol
   */
  function recoverERC20(address tokenAddress, uint256 tokenAmount) external {
    require(
      hasRole(RECOVER_ROLE, _msgSender()), 
      "FarmingPool::recoverERC20: You must possess the recover role to recover erc20"
    );
    require(
      tokenAddress != address(stakeToken), 
      "FarmingPool::recoverERC20: Cannot recover the staking token"
    );
    require(
      tokenAddress != address(rewardToken), 
      "FarmingPool::recoverERC20: Cannot recover the reward token"
    );

    IERC20(tokenAddress).safeTransfer(_msgSender(), tokenAmount);
    emit Recovered(tokenAddress, tokenAmount);
  }
}