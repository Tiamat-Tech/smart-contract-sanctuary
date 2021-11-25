// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./lib/reentrancy-guard.sol";
import "./lib/pausable.sol";
import "./lib/owned.sol";
import "./base/ERC20.sol";

contract EpikStaking is ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct WithdrawingRequest { 
        uint256 withdrawTime;
        uint256 pendingDays;
        uint256 amount;
        bool isCompleted;
    }

    address public withdrawRunner;
    uint256 public cooldown = 10 days;
    mapping(address => mapping(uint256 => WithdrawingRequest)) public userWithdrawingRequest;

    uint256 public withdrawFee = 0;
    address public withdrawVault;

    /* ========== STATE VARIABLES ========== */

    IERC20 public stakingToken;
    
    uint256 public periodFinish = 0;

    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 7 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    uint256 private _totalClaimedRewards = 0;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    string public name = "PRIME";
    string public symbol = "PRIME";
    uint8 constant public decimals = 18;

    mapping(address => uint256) private _primeBalances;

    uint256[] private tier_thresholds = [100, 1000, 10000];

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _stakingToken) Owned(_owner) {
        stakingToken = IERC20(_stakingToken);
        withdrawRunner = _owner;
    }

    /* ========== VIEWS ========== */

    function primeBalanceOf(address account) external view returns (uint256) {
        return _primeBalances[account];
    }

    function membershipOf(address account) external view returns (uint256) {
        for (uint i = 0; i < tier_thresholds.length; i++) {
            if (_primeBalances[account] < tier_thresholds[i] * (10 ** decimals)) {
                return i;
            }
        }
        return tier_thresholds.length;
    }

    function getThresholds() external view returns (uint256 _total, uint256[] memory _thresholds) {
        _total = tier_thresholds.length;
        _thresholds = tier_thresholds;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function totalClaimedRewards() external view returns (uint256) {
        return _totalClaimedRewards;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }


    function lastTimeRewardApplicable() public view returns (uint256) {
        return min(block.timestamp, periodFinish);
    }

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

    function earned(address account) public view returns (uint256) {
        return
            _balances[account]
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount)
        external
        nonReentrant
        notPaused
    {
        _updateReward(msg.sender);

        require(amount > 0, "Cannot stake 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        // Prime balance
        _primeBalances[msg.sender] = _primeBalances[msg.sender].add(amount);

        emit Staked(msg.sender, amount);
        emit Transfer(address(0), msg.sender, amount);      // Mint Prime
    }

    function withdrawRequest(uint256 amount) public payable {
        if (withdrawFee > 0) {
            require(withdrawFee == msg.value, "fee is not correct");

            if (withdrawVault != address(0)) {
                (bool sent,) = withdrawVault.call{value: msg.value}("");
                require(sent, "Failed to send Fee");
            }
        }

        uint256 currentTime = block.timestamp;

        require(
            userWithdrawingRequest[msg.sender][currentTime].withdrawTime == 0 &&
            userWithdrawingRequest[msg.sender][currentTime].pendingDays == 0 &&
            userWithdrawingRequest[msg.sender][currentTime].amount == 0 &&
            userWithdrawingRequest[msg.sender][currentTime].isCompleted == false, 
            "duplicated"
        );

        require(amount > 0, "Cannot withdraw 0");
        require(_balances[msg.sender] >= amount, "insufficient staking amount");

        userWithdrawingRequest[msg.sender][currentTime] = WithdrawingRequest(currentTime, cooldown, amount, false);

        emit WithdrawRequested(msg.sender, cooldown, currentTime + cooldown, amount, currentTime);
    }

    function withdraw(address _receiver, uint256 _withdrawTime)
        public
        nonReentrant
    {
        require(msg.sender == withdrawRunner, "only withdrawRunner can withdraw");
        require(_receiver != address(0), "no receiver");

        require(
            userWithdrawingRequest[_receiver][_withdrawTime].withdrawTime != 0 &&
            userWithdrawingRequest[_receiver][_withdrawTime].pendingDays != 0 &&
            userWithdrawingRequest[_receiver][_withdrawTime].amount != 0,
            "no withdrawn request"
        );

        require(userWithdrawingRequest[_receiver][_withdrawTime].isCompleted == false, "already withdrew");

        uint256 withdrawTime = userWithdrawingRequest[_receiver][_withdrawTime].withdrawTime;
        uint256 pendingDays = userWithdrawingRequest[_receiver][_withdrawTime].pendingDays;
        uint256 amount = userWithdrawingRequest[_receiver][_withdrawTime].amount;

        require(block.timestamp >= (withdrawTime + pendingDays), "pending");

        _updateReward(_receiver);

        _totalSupply = _totalSupply.sub(amount);
        _balances[_receiver] = _balances[_receiver].sub(amount);
        stakingToken.safeTransfer(_receiver, amount);

        // Prime balance
        _primeBalances[_receiver] = _primeBalances[_receiver].sub(amount);

        userWithdrawingRequest[_receiver][_withdrawTime].isCompleted = true;

        emit Withdrawn(_receiver, amount);
        emit Transfer(_receiver, address(0), amount);
    }

    function withdrawMulti(address[] memory _receivers, uint256[] memory _withdrawTimes)
        public 
        nonReentrant
    {
        for(uint i = 0; i < _receivers.length; i++) {
            withdraw(_receivers[i], _withdrawTimes[i]);
        }
    }

    function claimReward() public nonReentrant {

        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            
            // Sending ETH
            (bool sent,) = msg.sender.call{value: reward}("");
            require(sent, "Failed to send Ether");

            _totalClaimedRewards = _totalClaimedRewards.add(reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function notifyRewardAmount(uint256 reward)
        external
        onlyOwner
    {
        _updateReward(address(0));

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
        uint256 balance = address(this).balance;
        require(
            rewardRate <= balance.div(rewardsDuration),
            "Provided reward too high"
        );

        lastUpdateTime = block.timestamp;

        periodFinish = block.timestamp.add(rewardsDuration);

        emit RewardAdded(reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
    {
        // Cannot recover the staking token or the rewards token
        require(tokenAddress != address(stakingToken), "Cannot withdraw the staking or rewards tokens");
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
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

    function _updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function setName(string memory _name) onlyOwner public {
        name = _name;
    }

    function setSymbol(string memory _symbol) onlyOwner public {
        symbol = _symbol;
    }

    function updateThresholds(uint256 _index, uint256 _value) onlyOwner public {
        if (_index < tier_thresholds.length ) {
            tier_thresholds[_index] = _value;
        } else {
            tier_thresholds.push(_value);
        }
    }

    function setWithdrawRunner(address _withdrawRunner) onlyOwner() public {
        require(_withdrawRunner != address(0), "address is null");

        withdrawRunner = _withdrawRunner;
    }

    function setCooldown(uint256 _cooldown) onlyOwner() public {
        cooldown = _cooldown;
    }

    function setWithdrawFee(uint256 _fee) onlyOwner() public {
        withdrawFee = _fee;
    }

    function setWithdrawVault(address _vault) onlyOwner() public {
        withdrawVault = _vault;
    }

    fallback() external payable {}
    receive() external payable {}

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function seize() external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "still in reward period"
        );

        uint256 balance = address(this).balance;

        (bool sent,) = owner.call{value: balance}("");

        require(sent, "Failed");
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 tokens);

    event WithdrawRequested(address indexed withdrawer, uint256 cooldown, uint256 finishTime, uint256 amount, uint256 withdrawTime );
    event Withdrawn(address indexed user, uint256 amount);

}