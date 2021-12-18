// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


// Archangel Staking Pool (Gabriel).
// Stake Archa tokens to Earn.
// Have fun reading it. Hopefully it's bug-free. God bless.
contract Gabriel is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 time;
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 lastRewardBlock; // Last block number that ARCHAs distribution occurs.
        uint256 totalStaked; // Total Archa Staked in the Gabriel Staking Pool.
    }
    // Is Staking Open
    bool public canStake = false;
    // Has Staking Period ended
    bool public canUnstake = false;
    // The ARCHANGEL TOKEN!
    IERC20 public archa;
    // Dev address.
    address public devaddr;
    // Archa Team address.
    address public growthFundAddr;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total Rewards. This is the total number of ARCHA rewards that is in the pool
    uint256 public totalRewards = 0;
    // The exact time when ARCHANGEL mining starts.
    uint256 public startTime = 0;
    // The exact time when ARCHANGEL mining ends.
    uint256 public endTime = 0;
    // The exact number of seconds it will take for the pool to close.
    uint256 public tSecs;
    // The time when staking is still open.
    uint256 public waitPeriod;
    event Stake(address indexed user, uint256 indexed pid, uint256 amount);
    event Unstake(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        IERC20 _archa,
        address _devaddr,
        address _growthFundAddr
    ) {
        archa = _archa;
        devaddr = _devaddr;
        growthFundAddr = _growthFundAddr;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.timestamp > startTime ? block.timestamp : startTime;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                lastRewardBlock: lastRewardBlock,
                totalStaked: 0
            })
        );
    }

    function setValues(uint256 _startTime, uint256 _endTime, uint256 _totalRewards, uint256 _waitPeriod) public onlyOwner {
        require(_startTime > block.timestamp, "Start Time must be a future time");
        startTime = _startTime;
        canStake = true;

        require(_endTime > block.timestamp && _endTime > _startTime, "End Time must be greater than Start Time");
        endTime = _endTime;

        require(_startTime >0 && _endTime >0);
        tSecs = endTime.sub(startTime);

        require(_totalRewards > 0);
        totalRewards = _totalRewards;

        require(_waitPeriod > 0);
        waitPeriod = _waitPeriod;
    }

    // View function to see pending ARCHAs on frontend.
    function pendingArcha(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        if (block.timestamp < endTime) {
            PoolInfo storage pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][_user];
            uint256 time = user.time;
            uint256 lpSupply = pool.totalStaked;
            if (block.timestamp > pool.lastRewardBlock && lpSupply != 0) {
                uint256 blocks = block.timestamp.sub(pool.lastRewardBlock);
                time = time.add(blocks);
                uint256 reward = time * user.amount * totalRewards;
                uint256 supply = lpSupply * time;
                return reward.div(supply);
            }
        }
        if (block.timestamp > endTime) {
            PoolInfo storage pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][_user];
            uint256 lpSupply = pool.totalStaked;
            uint256 reward = tSecs * user.amount * totalRewards;
            uint256 supply = lpSupply * tSecs;
            return reward.div(supply);
        }
        return 0;
        
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.totalStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.timestamp;
            return;
        }
        uint256 tsTr = pool.totalStaked.add(totalRewards);
        uint256 LOR = pool.lpToken.balanceOf(address(this)).sub(tsTr);
        uint256 half = LOR.div(2);
        uint256 otherHalf = LOR.sub(half);
        archa.safeTransfer(devaddr, half);
        archa.safeTransfer(growthFundAddr, otherHalf);
        pool.lastRewardBlock = block.timestamp;
    }

    // Stake Archa tokens to Gabriel to accumulate rewards.
    function stake(uint256 _pid, uint256 _amount) public {
        if (block.timestamp > startTime + waitPeriod){
            canStake = false;
        }
        require(canStake == true, "Waiting Period has ended, pool is now locked");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        pool.totalStaked = pool.totalStaked.add(_amount);
        emit Stake(msg.sender, _pid, _amount);
    }

    // Unstake Archa tokens from Gabriel.
    function unstake(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (block.timestamp > endTime){
            canUnstake = true;
        }
        require(canUnstake == true, "Pool is still locked");
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 reward = tSecs * user.amount * totalRewards;
        uint256 supply = pool.totalStaked * tSecs;
        uint256 pending = reward.div(supply);
        safeArchaTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        pool.totalStaked = pool.totalStaked.sub(_amount);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Unstake(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        pool.totalStaked = pool.totalStaked.sub(user.amount);
    }

    // Safe archa transfer function, just in case if rounding error causes pool to not have enough ARCHAs.
    function safeArchaTransfer(address _to, uint256 _amount) internal {
        uint256 archaBal = totalRewards;
        if (_amount > archaBal) {
            archa.transfer(_to, archaBal);
        } else {
            archa.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

    // Update Growth Fund Address.
    function growthFund(address _growthFundAddr) public onlyOwner {
        growthFundAddr = _growthFundAddr;
    }
}