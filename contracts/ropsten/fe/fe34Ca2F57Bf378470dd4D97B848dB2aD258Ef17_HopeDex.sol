pragma solidity >0.4.18 < 0.8.0;

import './Libs.sol';

contract ETHDistributorWrapper {

    using SafeMath for uint256;
    uint256 private _totalSupply;
    address deployer = msg.sender;

    mapping(address => uint256) private _balances;

    function totalSupply() public view returns(uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns(uint256) {
        return _balances[account];
    }

    function stake(uint256 amount, address forAddress) public {
        _totalSupply = _totalSupply.add(amount);
        _balances[forAddress] = _balances[forAddress].add(amount);
    }

    function withdraw(uint256 amount, address forAddress) public {
        _totalSupply = _totalSupply.sub(amount);
        _balances[forAddress] = _balances[forAddress].sub(amount);
    }
}


contract ETHDistributor is ETHDistributorWrapper{
    uint256 public DURATION = 14 days;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    address public hopeContract;

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    modifier checkAccess(){
        require(msg.sender == hopeContract ||
            msg.sender == deployer
        , "!checkAccess");
        _;
    }

    function lastTimeRewardApplicable() public view returns(uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns(uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e6).div(totalSupply())
        );
    }

    function earned(address account) public view returns(uint256) {
        return balanceOf(account).mul(
            rewardPerToken().sub(userRewardPerTokenPaid[account])
        ).div(1e6).add(rewards[account]);
    }

    function stake(uint256 amount, address forAddress) public checkAccess updateReward(forAddress) {
        super.stake(amount, forAddress);
    }

    function withdraw(uint256 amount, address forAddress) public checkAccess updateReward(forAddress) {
        super.withdraw(amount, forAddress);
    }

    function getReward(address sender) public checkAccess updateReward(sender) {
        uint256 reward = earned(sender);
        if (reward > 0) {
            rewards[sender] = 0;
        }
    }

    function notifyRewardAmount(uint256 reward) public checkAccess updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(DURATION);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(DURATION);
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(DURATION);
    }

    function setHopeContract(address hope) public checkAccess{
        hopeContract = hope;
    }
}