// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './IStakingRewards.sol';
import './Readable.sol';


// Based on: synthetix/contracts/StakingRewards.sol
contract StakingRewards is IStakingRewards, Ownable, Readable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    IERC20 immutable public rewardsToken;
    IERC20 immutable public stakingToken;
    uint public periodFinish;
    uint public rewardRate;
    uint public lastUpdateTime;
    uint public rewardPerTokenStored;

    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint) public rewards;

    uint private _totalSupply;
    mapping(address => uint) private _balances;

    constructor(address _owner, IERC20 _rewardsToken, IERC20 _stakingToken) {
        require(_rewardsToken != _stakingToken, 'Cannot reward with staking token');
        transferOwnership(_owner);
        rewardsToken = _rewardsToken;
        stakingToken = _stakingToken;
    }

    function totalSupply() external override view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) external override view returns (uint) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public override view returns (uint) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public override view returns (uint) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
        );
    }

    function earned(address account) public override view returns (uint) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external override view returns (uint) {
        return rewardRate.mul(till(periodFinish));
    }

    function stake(uint amount) external override updateReward(msg.sender) {
        require(amount > 0, 'Cannot stake 0');
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint amount) public override updateReward(msg.sender) {
        require(amount > 0, 'Cannot withdraw 0');
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public override updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward == 0) {
            return;
        }
        rewards[msg.sender] = 0;
        rewardsToken.safeTransfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function exit() external override {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    // Set new period finish or change unallocated rewards remaining period.
    function updatePeriodFinish(uint newPeriodFinish) public onlyOwner updateReward(address(0)) {
        require(not(passed(newPeriodFinish)), 'Update period finish first');
        uint oldPeriodFinish = periodFinish;
        require(oldPeriodFinish != newPeriodFinish, 'Should be different');
        uint remaining = till(oldPeriodFinish);
        uint leftover = remaining.mul(rewardRate);
        uint newRemaining = till(newPeriodFinish);
        rewardRate = leftover.div(newRemaining);
        periodFinish = newPeriodFinish;
        emit PeriodFinishUpdated(newPeriodFinish);
    }

    // Add more rewards for the remaining period.
    // Make sure to have something staked already, otherwise some rewards will be left locked.
    function addRewardAmount(uint reward) public onlyOwner updateReward(address(0)) {
        uint localPeriodFinish = periodFinish;
        require(not(passed(localPeriodFinish)), 'Update period finish first');
        require(reward > 0, 'Cannot add 0');
        uint remaining = till(localPeriodFinish);
        uint leftover = remaining.mul(rewardRate);
        rewardRate = reward.add(leftover).div(remaining);

        rewardsToken.safeTransferFrom(msg.sender, address(this), reward);
        emit RewardAdded(reward);
    }

    // Reduce unallocated rewards for the remaining period.
    function reduceRewardAmount(uint reduceBy, address to) external onlyOwner updateReward(address(0)) {
        uint localPeriodFinish = periodFinish;
        require(not(passed(localPeriodFinish)), 'Nothing to reduce');
        require(reduceBy > 0, 'Cannot reduce by 0');
        uint remaining = till(localPeriodFinish);
        uint leftover = remaining.mul(rewardRate);
        reduceBy = Math.min(leftover, reduceBy);
        rewardRate = leftover.sub(reduceBy).div(remaining);

        rewardsToken.safeTransfer(to, reduceBy);
        emit RewardReduced(reduceBy);
    }

    function newReward(uint newPeriodFinish, uint reward) external {
        updatePeriodFinish(newPeriodFinish);
        addRewardAmount(reward);
    }

    function recoverERC20(IERC20 token, uint amount, address to) external onlyOwner {
        require(token != stakingToken, 'Cannot recover the staking token');
        require(token != rewardsToken, 'Reduce reward amount instead');
        token.safeTransfer(to, amount);
        emit Recovered(token, amount);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    event PeriodFinishUpdated(uint newPeriodFinish);
    event RewardAdded(uint reward);
    event RewardReduced(uint reduceBy);
    event Staked(address indexed user, uint amount);
    event Withdrawn(address indexed user, uint amount);
    event RewardPaid(address indexed user, uint reward);
    event Recovered(IERC20 token, uint amount);
}