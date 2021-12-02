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
        uint256 withdrawableAmount;
        uint256 requestedTime;
        uint256 requestedAmount;
    }

    uint256 public cooldown = 12 days;

    mapping(address => WithdrawingRequest) public userWithdrawingRequest;

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

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _stakingToken) Owned(_owner) {
        stakingToken = IERC20(_stakingToken);
    }

    /* ========== VIEWS ========== */

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
        require(amount > 0, "Stake: Cannot stake 0");

        if (userWithdrawingRequest[msg.sender].requestedTime > 0) {
            require((userWithdrawingRequest[msg.sender].requestedTime + cooldown) <= block.timestamp, "Stake: withdraw request still in pending");
        }

        _updateReward(msg.sender);
       
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount);
    }

    function withdrawRequest(uint256 amount) external payable {
        require(amount > 0, "Withdraw Request: Cannot withdraw request 0");

        WithdrawingRequest memory prevRequest = userWithdrawingRequest[msg.sender];
        uint256 currentTime = block.timestamp;

        // Check cooldown status
        if (prevRequest.requestedTime > 0) {
            require((prevRequest.requestedTime + cooldown) <= currentTime, "Withdraw Request: withdraw request still in pending");
        }

        if (withdrawFee > 0) {
            require(withdrawFee == msg.value, "Withdraw Request: fee is not correct");

            if (withdrawVault != address(0)) {
                (bool sent,) = withdrawVault.call{value: msg.value}("");
                require(sent, "Withdraw Request: Failed to send Fee");
            }
        }

        require(_balances[msg.sender] >= (amount + prevRequest.withdrawableAmount + prevRequest.requestedAmount), "Withdraw Request: Can not request the amount. Insufficient staking amount");

        userWithdrawingRequest[msg.sender].withdrawableAmount = prevRequest.withdrawableAmount + prevRequest.requestedAmount;
        userWithdrawingRequest[msg.sender].requestedAmount = amount;
        userWithdrawingRequest[msg.sender].requestedTime = currentTime;

        emit WithdrawRequested(cooldown, msg.sender, currentTime, amount);
    }

    function withdraw(uint256 amount)
        external
        nonReentrant
    {
        require(amount > 0, "Withdraw: Cannot withdraw 0");

        WithdrawingRequest memory prevRequest = userWithdrawingRequest[msg.sender];

        // Check cooldown status and update withdrawRequesting status
        if ((prevRequest.requestedTime + cooldown) <= block.timestamp) {
            prevRequest.withdrawableAmount = prevRequest.withdrawableAmount + prevRequest.requestedAmount;
        }

        require(_balances[msg.sender] >= amount, "Withdraw: Can not withdraw the amount. Insufficient balance");
        require(prevRequest.withdrawableAmount >= amount, "Withdraw: Can not withdraw the amount. Insufficient withdrawable balance");

        userWithdrawingRequest[msg.sender].withdrawableAmount = prevRequest.withdrawableAmount - amount;
        userWithdrawingRequest[msg.sender].requestedTime = 0;
        userWithdrawingRequest[msg.sender].requestedAmount = 0;

        _updateReward(msg.sender);

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakingToken.safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function withdrawCancel() external
    {
        WithdrawingRequest memory request = userWithdrawingRequest[msg.sender];

        require(request.requestedTime > 0, "Withdraw Cancel: no request");
        require((request.requestedTime + cooldown) > block.timestamp, "Withdraw Cancel: no pending request");

        userWithdrawingRequest[msg.sender].requestedTime = 0;
        userWithdrawingRequest[msg.sender].requestedAmount = 0;

        emit WithdrawCancelled(msg.sender, request.requestedTime, request.requestedAmount);
    }

    function claimReward() public nonReentrant {

        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            
            // Sending ETH
            (bool sent,) = msg.sender.call{value: reward}("");
            require(sent, "Claim: Failed to send Ether");

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
            "Notify Reward: Provided reward too high"
        );

        lastUpdateTime = block.timestamp;

        periodFinish = block.timestamp.add(rewardsDuration);

        emit RewardAdded(reward);
    }

    function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Set Rewards Duration: Previous rewards period must be complete before changing the duration for the new period"
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

    function setName(string memory _name) onlyOwner external {
        name = _name;
    }

    function setSymbol(string memory _symbol) onlyOwner external {
        symbol = _symbol;
    }

    function setCooldown(uint256 _cooldown) onlyOwner() external {
        cooldown = _cooldown;
    }

    function setWithdrawFee(uint256 _fee) onlyOwner() external {
        withdrawFee = _fee;
    }

    function setWithdrawVault(address _vault) onlyOwner() external {
        withdrawVault = _vault;
    }

    fallback() external payable {}
    receive() external payable {}

    function getBalance() external view returns (uint) {
        return address(this).balance;
    }

    function seize() external onlyOwner {
        require(
            block.timestamp > periodFinish,
            "Seize: still in reward period"
        );

        uint256 balance = address(this).balance;

        (bool sent,) = owner.call{value: balance}("");

        require(sent, "Seize: Failed");
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);

    event WithdrawRequested(uint256 cooldown, address indexed withdrawer, uint256 withdrawTime, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event WithdrawCancelled(address indexed user, uint256 cooldown, uint256 amount);
}