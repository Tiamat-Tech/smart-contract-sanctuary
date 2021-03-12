// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


// Inheritance
// import "./interfaces/IStakingRewards.sol";
// import "./RewardsDistributionRecipient.sol";
// import "./Pausable.sol";
import "./interfaces/IMasterChef.sol";


// https://docs.synthetix.io/contracts/source/contracts/stakingrewards
contract StakingRewards is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant PID = 0; 

    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SUSHIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSushiPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSushiPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that SUSHIs distribution occurs.
        uint256 accSushiPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
    }

    /* ========== STATE VARIABLES ========== */

    IERC20 public rewardsTokenXFT;
    IERC20 public rewardsTokenSUSHI;

    IERC20 public stakingToken;
    IMasterChef public masterChef;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 30 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewardsXFT;
    mapping(address => uint256) public rewardsSUSHI;


    uint256 private _totalSupply;

    //-------------------------------------------------------------------------------
    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;
    //-------------------------------------------------------------------------------
    

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewardsXFT[account] = earnedXFT(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event XFTRewardPaid(address indexed user, uint256 reward);
    event SUSHIRewardPaid(address indexed user, uint256 reward);    
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _rewardsTokenXFT,
        address _rewardsTokenSUSHI,
        address _stakingToken,
        address _masterChef
    ) Ownable() {
        rewardsTokenXFT = IERC20(_rewardsTokenXFT);
        rewardsTokenSUSHI = IERC20(_rewardsTokenSUSHI);
        stakingToken = IERC20(_stakingToken);
        masterChef = IMasterChef(_masterChef);
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return userInfo[account].amount;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    function earnedXFT(address account) public view returns (uint256) {
        return userInfo[account].amount.mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewardsXFT[account]);
    }

    // View function to see pending SUSHIs on frontend.
    function pendingSushi(address _user) external view returns (uint256) {

        UserInfo storage user = userInfo[_user];
        uint256 accSushiPerShare = poolInfo.accSushiPerShare;
        uint256 lpSupply = poolInfo.lpToken.balanceOf(address(masterChef));
        if (block.number > poolInfo.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = masterChef.getMultiplier(poolInfo.lastRewardBlock, block.number);
            uint256 sushiReward = multiplier.mul(masterChef.sushiPerBlock()).mul(poolInfo.allocPoint).div(masterChef.totalAllocPoint());
            accSushiPerShare = accSushiPerShare.add(sushiReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accSushiPerShare).div(1e12).sub(user.rewardDebt);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Stake: cant stake 0");
        _totalSupply = _totalSupply.add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        stakingToken.approve(address(masterChef), amount);
        masterChef.deposit(PID, amount);

        // part from MasterChef--------------------------------------------------------
        //masterChef.updatePool(PID);
        (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accSushiPerShare
        ) = masterChef.poolInfo(PID);

        poolInfo = PoolInfo(
            IERC20(lpToken),
            allocPoint,
            lastRewardBlock,
            accSushiPerShare
        );
 
        UserInfo storage user = userInfo[msg.sender];

        if (user.amount > 0) {
            rewardsSUSHI[msg.sender] = rewardsSUSHI[msg.sender].add(user.amount.mul(poolInfo.accSushiPerShare).div(1e12).sub(user.rewardDebt));
        }
        user.amount = user.amount.add(amount);
        user.rewardDebt = user.amount.mul(poolInfo.accSushiPerShare).div(1e12);
        // ----------------------------------------------------------------------------

        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Withdraw: cant withdraw 0");
        _totalSupply = _totalSupply.sub(amount);

        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "Withdraw: insuficient funds");

        masterChef.withdraw(PID, amount);
        // part from MasterChef--------------------------------------------------------
        (
            address lpToken,
            uint256 allocPoint,
            uint256 lastRewardBlock,
            uint256 accSushiPerShare
        ) = masterChef.poolInfo(PID);

        poolInfo = PoolInfo(
            IERC20(lpToken),
            allocPoint,
            lastRewardBlock,
            accSushiPerShare
        );

        rewardsSUSHI[msg.sender] = rewardsSUSHI[msg.sender].add(user.amount.mul(poolInfo.accSushiPerShare).div(1e12).sub(user.rewardDebt));
        
        user.amount = user.amount.sub(amount);
        user.rewardDebt = user.amount.mul(poolInfo.accSushiPerShare).div(1e12);
        poolInfo.lpToken.safeTransfer(address(msg.sender), amount);
        // ----------------------------------------------------------------------------

        //stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // // Withdraw without caring about rewards. EMERGENCY ONLY.
    // function emergencyWithdraw(uint256 _pid) public {
    //     PoolInfo storage pool = poolInfo[_pid];
    //     UserInfo storage user = userInfo[_pid][msg.sender];
    //     pool.lpToken.safeTransfer(address(msg.sender), user.amount);
    //     emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    //     user.amount = 0;
    //     user.rewardDebt = 0;
    // }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 rewardXFT = rewardsXFT[msg.sender];    
        uint256 rewardSUSHI = rewardsSUSHI[msg.sender];

        if (rewardXFT > 0) {
            rewardsXFT[msg.sender] = 0;
            rewardsTokenXFT.safeTransfer(msg.sender, rewardXFT);
            emit XFTRewardPaid(msg.sender, rewardXFT);
        }
        
        if (rewardSUSHI > 0) {
            rewardsSUSHI[msg.sender] = 0;
            safeSushiTransfer(msg.sender, rewardSUSHI);
            emit SUSHIRewardPaid(msg.sender, rewardSUSHI);
        }
    }

    function exit() external {
        withdraw(userInfo[msg.sender].amount);
        getReward();
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsTokenXFT.balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

    // End rewards emission earlier
    function updatePeriodFinish(uint timestamp) external onlyOwner updateReward(address(0)) {
        periodFinish = timestamp;
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Previous rewards period must be complete before changing the duration for the new period"
        );
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(rewardsDuration);
    }

    // Safe sushi transfer function, just in case if rounding error causes pool to not have enough SUSHIs.
    function safeSushiTransfer(address _to, uint256 _amount) internal {
        uint256 sushiBal = rewardsTokenSUSHI.balanceOf(address(this));
        if (_amount > sushiBal) {
            rewardsTokenSUSHI.safeTransfer(_to, sushiBal);
        } else {
            rewardsTokenSUSHI.safeTransfer(_to, _amount);
        }
    }

    function updatePoolInfo() internal {
        masterChef.updatePool(PID);
        (
            address _lpToken,
            uint256 _allocPoint,
            uint256 _lastRewardBlock,
            uint256 _accSushiPerShare
        ) = masterChef.poolInfo(PID);

        poolInfo = PoolInfo(IERC20(_lpToken), _allocPoint, _lastRewardBlock, _accSushiPerShare);
    }
}