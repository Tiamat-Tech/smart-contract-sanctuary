// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libraries/SafeMath.sol";
import "./libraries/TransferHelper.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/Math.sol";
import "./utils/Context.sol";
import "./utils/Ownable.sol";
import "./interfaces/ERC20Interface.sol";
import "./interfaces/IWETH.sol";
contract StakingRewards is Context, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */
    address public immutable weth;
    address private _rewardsTokenAddress;
    address private _stakingTokenAddress;
    ERC20Interface private _rewardsToken;
    ERC20Interface private _stakingToken;
    uint256 public poolPeriod = 0;
    uint256 public startTime = 0;
    uint256 public poolAmount = 0;

    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

   

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address owner_,
        address rewardsToken_,
        address stakingToken_,
        address _weth
    ) Ownable(owner_) {
        _rewardsTokenAddress = rewardsToken_;
        _stakingTokenAddress = stakingToken_;
        _rewardsToken = ERC20Interface(rewardsToken_);
        _stakingToken = ERC20Interface(stakingToken_);
        weth = _weth;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function rewardsToken() external view returns (address) {
        return _rewardsTokenAddress;
    }

    function stakingToken() external view returns (address) {
        return _stakingTokenAddress;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount) external nonReentrant poolStarted {
        require(amount > 0, "StakingRewards::stake: Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        TransferHelper.safeTransferFrom(_stakingTokenAddress, msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function _withdraw(uint256 amount) internal nonReentrant poolEnded{
        require(amount > 0, "StakingRewards::withdraw: Cannot withdraw 0");
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        TransferHelper.safeTransfer(_stakingTokenAddress, msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward(address _account) public view returns (uint256) {
        if(_totalSupply == 0) return 0;
        uint256 reward = poolAmount * _balances[_account] / _totalSupply;
        return reward;
    }

    function claimReward() public nonReentrant {

        uint256 reward = getReward(msg.sender);
        if(reward > _rewardsToken.balanceOf(address(this)))
        {
            reward = _rewardsToken.balanceOf(address(this));
        }
        if (reward > 0) {
            rewards[msg.sender] += reward;
            if(_rewardsTokenAddress == weth)
            {
                IWETH(weth).withdraw(reward);
                TransferHelper.safeTransferETH(msg.sender, reward);
            }
            else
            {
                TransferHelper.safeTransfer(_rewardsTokenAddress, msg.sender, reward);
            }
            emit RewardPaid(msg.sender, reward);
        }
    }

    function withdraw(uint256 amount) external {
        claimReward();
        _withdraw(amount);

    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external payable onlyOwner {
        require(tokenAddress != _stakingTokenAddress, "StakingRewards::recoverERC20: Cannot withdraw staking token");

        if(tokenAddress == address(0)) {
            TransferHelper.safeTransferETH(msg.sender, tokenAmount);
        }
        else if(tokenAddress == weth)
        {
            IWETH(weth).withdraw(tokenAmount);
            TransferHelper.safeTransferETH(msg.sender, tokenAmount);
        }
        else{
            TransferHelper.safeTransfer(tokenAddress, msg.sender, tokenAmount);
        }
        emit Recovered(tokenAddress, tokenAmount);
    }
    function startStake(uint256 _startTime, uint256 _poolPeriod, uint256 _poolAmount) external payable onlyOwner poolEnded{
        require(_startTime > block.timestamp, "start time is invalid");
        startTime = _startTime;
        poolPeriod = _poolPeriod;
        if(_rewardsTokenAddress == weth) {
            IWETH(weth).deposit{value: _poolAmount}();
        }
        else{
            TransferHelper.safeTransferFrom(_rewardsTokenAddress, msg.sender, address(this), _poolAmount);
        }
        poolAmount = _poolAmount;
        emit RewardAdded(poolAmount);
    }
    /* ========== MODIFIERS ========== */
    modifier poolStarted() {
        require(startTime != 0 && block.timestamp > startTime && block.timestamp < startTime + poolPeriod, "pool not started");
        _;
    }
    modifier poolEnded() {
        require(startTime == 0 || block.timestamp > startTime + poolPeriod, "pool not ended");
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event Recovered(address token, uint256 amount);
}