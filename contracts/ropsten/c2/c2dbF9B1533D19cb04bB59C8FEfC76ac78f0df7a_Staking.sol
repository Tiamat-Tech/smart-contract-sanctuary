// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./IERC20.sol";

contract Staking{
    IERC20 public rewardsToken;
    IERC20 public stakingToken;

    uint public globalRewardTime;
    uint public globalRewardPrecent;
    uint public globalfreezeTime;
    address public owner;

    mapping(address => uint) public rewards;
    mapping(address => uint) public lastUpdateTimes;
    mapping(address => uint) public freezeUpdateTimes;

    uint public _totalSupply;
    mapping(address => uint) private _balances;

    constructor(address _stakingToken, address _rewardsToken, uint _rewardTime, uint _globalRewardPrecent, uint _globalfreezeTime) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
        globalRewardTime = _rewardTime;
        globalRewardPrecent = _globalRewardPrecent;
        owner = msg.sender;
        globalfreezeTime = _globalfreezeTime;
    }

    modifier updateReward(address account) {
        _calcReward(account);
        _;
    }

    modifier checkFreezeTime() {
        uint withdrawTime = block.timestamp - freezeUpdateTimes[msg.sender];
        require(withdrawTime > globalfreezeTime, "Withdraw available after 10 min");
        _;
    } 

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function stake(uint _amount) external updateReward(msg.sender) {
        _totalSupply += _amount; 
        _balances[msg.sender] += _amount;
        lastUpdateTimes[msg.sender] = block.timestamp;
        freezeUpdateTimes[msg.sender] = block.timestamp;

        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    function unstake(uint _amount) external updateReward(msg.sender) checkFreezeTime{
        
        _totalSupply -= _amount;
        _balances[msg.sender] -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function claim() external updateReward(msg.sender) checkFreezeTime{
        uint reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        rewardsToken.transfer(msg.sender, reward);
    }

    function _calcReward(address account) internal {
        uint reward = ((block.timestamp - lastUpdateTimes[account]) / globalRewardTime)
         * ((_balances[account] * globalRewardPrecent) / 10000);
         if(reward != 0){
             rewards[account] += reward;
             lastUpdateTimes[account] += ((block.timestamp - lastUpdateTimes[account]) / globalRewardTime) * globalRewardTime;
         }
    }

    function getRewards(address _user) external updateReward(_user) returns(uint){
        return rewards[_user];
    }

    function totalSupply() external view returns(uint){
        return _totalSupply;
    }

    function setGlobalRewardTime(uint time) external onlyOwner{
        globalRewardTime = time;
    }

    function setGlobalRewardPrecent(uint time) external onlyOwner{
        globalRewardPrecent = time;
    }

    function setGlobalfreezeTime(uint time) external onlyOwner{
        globalfreezeTime = time;
    }
}