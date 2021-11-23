// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./NftPad.sol";

contract NftpadFarmingPool is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 public stakingToken;
    IERC20 public rewardsToken;
    NftPad public nftPad;
    address public rewardsDistribution;
    uint256 public rewardRate = 0;
    uint256 private _totalSupply = 0;
    uint256 public periodFinish = 0;
    uint256 public minPoint = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) private _balances;

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _rewardsDistribution,
        address _stakingToken,
        address _rewardsToken,
        address _nftPad
    ) public {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        nftPad = NftPad(_nftPad);
        rewardsDistribution = _rewardsDistribution;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /** Calculates the last time reward could be paid up until this moment for specific reward token
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /** Calculates how many rewards tokens you should get per 1 staked token until last applicable time (in most cases it is now) for specific token
     */
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(_totalSupply)
            );
    }

    /** Calculates how much rewards a user has earned.
     */
    function earned(address account) public view returns (uint256) {
        return
            _balances[account]
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward, uint256 rewardsDuration)
        external
        updateReward(address(0))
    {
        require(
            msg.sender == rewardsDistribution,
            "Caller is not Reward distribution contracts"
        );
        // require(reward <= rewardsToken.balanceOf(rewardsDistribution), "Provided reward too high");

        periodFinish = block.timestamp.add(rewardsDuration * 1 days);
        lastUpdateTime = block.timestamp;
        rewardRate = reward.div(rewardsDuration * 1 days);
        emit RewardAdded(reward);
    }

    function setMinPoint(uint256 rewardMinPoint) external nonReentrant {
        minPoint = rewardMinPoint;
        emit MinPointAdded(rewardMinPoint);
    }

    /* ========== MODIFIERS ========== */
    /** Modifier that re-calculates the rewards per user on user action
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function stake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot stake 0");
        uint256 totalPoint = nftPad.userPoints(msg.sender);

        require(totalPoint >= minPoint, "Minimum Point not enough");

        _balances[msg.sender] = _balances[msg.sender].add(amount);
        _totalSupply = _totalSupply.add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, address(stakingToken), amount);
    }

    function unstake(uint256 amount)
        external
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdrawn 0");
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        _totalSupply = _totalSupply.sub(amount);
        emit UnStaked(msg.sender, address(stakingToken), amount);
    }

    function claim() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
        }
        emit RewardPaid(msg.sender, reward);
    }

    /* ========== EVENTS ========== */
    event MinPointAdded(uint256 minPoint);
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, address token, uint256 amount);
    event UnStaked(address indexed user, address token, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
}