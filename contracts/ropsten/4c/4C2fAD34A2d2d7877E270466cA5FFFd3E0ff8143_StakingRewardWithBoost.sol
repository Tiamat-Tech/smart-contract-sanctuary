pragma solidity ^0.8.2;

import { IERC20 } from "IERC20.sol";
import { Math } from  "Math.sol";
import { SafeERC20 } from "SafeERC20.sol";
import { ReentrancyGuard } from "ReentrancyGuard.sol";
import { IVotingEscrow } from "IVotingEscrow.sol";

contract StakingRewardWithBoost is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    IERC20 public votingEscrow;
    uint256 public periodFinish = 0;
    uint256 public maxRewardRate = 0;
    uint256 public rewardsDuration;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public immutable initTime;
    uint256 public immutable boostWarmUp;
    uint256 public constant TOKENLESS_PRODUCTION = 40;
    address public rewardsDistribution;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 internal _totalSupply;
    mapping(address => uint256) internal _balances;
    uint256 internal _boostSupply;
    mapping(address => uint256) internal _boostBalances;

    mapping(address => uint256) public lastUpdateTimeOfUser;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken,
        address _votingEscrow,
        uint256 _rewardsDuration,
        uint256 _boostWarmUp
    ) public {
        rewardsToken = IERC20(_rewardsToken);
        stakingToken = IERC20(_stakingToken);
        votingEscrow = IERC20(_votingEscrow);
        rewardsDistribution = _rewardsDistribution;
        rewardsDuration = _rewardsDuration;
        initTime = block.timestamp;
        boostWarmUp = _boostWarmUp;
    }

    /* ========== INTERNAL FUNCTIONS ========== */
    function _updateLiquidityLimit(address addr, uint256 l, uint256 L) internal {
        uint256 votingBalance = votingEscrow.balanceOf(addr);
        uint256 votingTotal = votingEscrow.totalSupply();

        uint256 lim = l * TOKENLESS_PRODUCTION / 100;
        if (votingTotal > 0 && block.timestamp >= initTime + boostWarmUp) {
            lim += (L * votingBalance / votingTotal) * (100 - TOKENLESS_PRODUCTION) / 100;
        }

        lim = l < lim ? l : lim;
        uint256 oldBal = _boostBalances[addr];
        _boostBalances[addr] = lim;
        uint256 newSupply = _boostSupply + lim - oldBal;
        _boostSupply = newSupply;

        lastUpdateTimeOfUser[addr] = block.timestamp;
        emit UpdateLiquidityLimit(addr, l, L, lim, _boostSupply);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function boostSupply() external view returns (uint256) {
        return _boostSupply;
    }

    function boostBalanceOf(address account) external view returns (uint256) {
        return _boostBalances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_boostSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored + (
                (lastTimeRewardApplicable() - lastUpdateTime) * maxRewardRate * 1e18 / _boostSupply
            );
    }

    function earnedReward(address account) public view returns (uint256) {
        return _boostBalances[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18 + rewards[account];
    }

    function getRewardForDuration() external view returns (uint256) {
        return maxRewardRate * rewardsDuration;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply += amount;
        _balances[msg.sender] += amount;
        _updateLiquidityLimit(msg.sender, _balances[msg.sender], _totalSupply);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        _updateLiquidityLimit(msg.sender, _balances[msg.sender], _totalSupply);
        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
        _updateLiquidityLimit(msg.sender, _balances[msg.sender], _totalSupply);
    }

    function exit() public {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    function userUpdateBoost() external returns (bool) {
        _updateLiquidityLimit(msg.sender, _balances[msg.sender], _totalSupply);
        return true;
    }

    function kick(address addr) external {
        uint256 tLast = lastUpdateTimeOfUser[addr];
        uint256 tVE = IVotingEscrow(address(votingEscrow)).user_point_history__ts(
            addr, IVotingEscrow(address(votingEscrow)).user_point_epoch(addr)
        );

        require(IERC20(address(votingEscrow)).balanceOf(addr) == 0 || tVE > tLast, "kick not allowed");
        require(_boostBalances[addr] > _balances[addr] * TOKENLESS_PRODUCTION / 100, "kick not needed");

        _updateLiquidityLimit(addr, _balances[addr], _totalSupply);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward) external onlyRewardsDistribution updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            maxRewardRate = reward / rewardsDuration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * maxRewardRate;
            maxRewardRate = (reward + leftover) / rewardsDuration;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of maxRewardRate in the earnedReward and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));
        require(maxRewardRate <= balance / rewardsDuration, "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyRewardsDistribution() {
        require(msg.sender == rewardsDistribution, "Caller is not RewardsDistribution contract");
        _;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earnedReward(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event Withdrawn(address indexed user, uint256 amount);
    event UpdateLiquidityLimit(address indexed user, uint256 l, uint256 L, uint256 lim, uint256 workingSupply);
}