// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Archangel Staking Pool (Gabriel).
// Stake Archa tokens to Earn.
// Have fun reading it. Hopefully it's bug-free. God bless.
contract GabrielV2 is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 lastRewardBlock; // Last block number that ARCHAs distribution occurs.
        uint256 totalStaked; // Total Archa Staked in the Gabriel Staking Pool.
        uint256 forfeited; // To keep track of when a user left the pool using emergencyWithdraw
    }
    // Is Staking Open
    bool public canStake = false;
    // Wait Period
    bool public inWaitPeriod = false;
    // Has Lock Period ended
    bool public canUnstake = false; // use emergencyWithdraw if its urgent.
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
    // Total Rewards. This is the total number of reward tokens that is in the pool.
    uint256 public totalRewards;
    // The exact time when ARCHANGEL Staking Pool opens and users can start to stake.
    uint256 public openTime;
    // The time when staking is still open.
    uint256 public waitPeriod;
    // The exact time when staking is closed and mining starts.
    uint256 public lockTime;
    // The number of seconds during which the pool remains closed and users cannot stake or unstake.
    uint256 public lockDuration;
    // The exact time when mining ends, pool is unlocked and users can harvest earnings.
    uint256 public unlockTime;
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
    // Remember to set time values before creating a pool.
    // Only create a pool when block.timestamp < openTime && block.timestamp < lockTime.
    function add(IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        require(lockTime > 0, "Set Time Values First");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = lockTime;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                lastRewardBlock: lastRewardBlock,
                totalStaked: 0,
                forfeited: 0
            })
        );
    }

    function setTimeValues(
        uint256 _openTime,
        uint256 _waitPeriod,
        uint256 _lockDuration
    ) public onlyOwner {
        require(
            _openTime > block.timestamp,
            "Start Time must be a future time"
        );
        openTime = _openTime;

        require(_waitPeriod > 0);
        waitPeriod = _waitPeriod;

        lockTime = openTime.add(waitPeriod);

        require(_lockDuration > 0);
        lockDuration = _lockDuration;

        require(
            lockTime > block.timestamp && lockTime + lockDuration > lockTime,
            "End Time must be greater than Start Time"
        );
        unlockTime = lockTime.add(lockDuration);
    }

    function setPoolReward(uint256 _value) public onlyOwner {
        require(_value > 0);
        totalRewards = _value;
    }

    // View function to see pending ARCHAs on frontend.
    function pendingArcha(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        if (block.timestamp > lockTime && block.timestamp < unlockTime) {
            PoolInfo storage pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][_user];
            uint256 supply = pool.totalStaked;
            if (block.timestamp > pool.lastRewardBlock && supply != 0) {
                uint256 blocks = block.timestamp.sub(pool.lastRewardBlock);
                uint256 reward = blocks * user.amount * totalRewards;
                uint256 lpSupply = supply * lockDuration;
                return reward.div(lpSupply);
            }
        }
        if (block.timestamp > unlockTime) {
            PoolInfo storage pool = poolInfo[_pid];
            UserInfo storage user = userInfo[_pid][_user];
            uint256 supply = pool.totalStaked;
            uint256 reward = lockDuration * user.amount * totalRewards;
            uint256 lpSupply = supply * lockDuration;
            return reward.div(lpSupply);
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

    // Update reward variables of a specific pool.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= openTime) {
            return;
        }
        if (block.timestamp > lockTime && block.timestamp < unlockTime) {
            canStake = false;
            inWaitPeriod = false;
            canUnstake = false;
        }
        if (
            block.timestamp > openTime &&
            block.timestamp < lockTime &&
            block.timestamp < unlockTime
        ) {
            canStake = true;
            inWaitPeriod = true;
            canUnstake = false;
        }
        if (block.timestamp > unlockTime && unlockTime > 0) {
            canUnstake = true;
            canStake = false;
            inWaitPeriod = false;
        }

        // Here we finally subtract forfeited from totalStaked to get the actual total staked.
        uint256 tStaked = pool.totalStaked.sub(pool.forfeited);
        uint256 tsTr = tStaked.add(totalRewards);
        uint256 poolBal = pool.lpToken.balanceOf(address(this));
        if (poolBal > tsTr) {
            uint256 LOR = poolBal.sub(tsTr);
            if (LOR > 0) {
                uint256 half = LOR.div(2);
                uint256 otherHalf = LOR.sub(half);
                pool.lpToken.safeTransfer(devaddr, half);
                pool.lpToken.safeTransfer(growthFundAddr, otherHalf);
            }
        }
    }

    // Stake Archa tokens to Gabriel to earn rewards.
    function stake(uint256 _pid, uint256 _amount) public {
        if (block.timestamp > lockTime && canStake == true) {
            canStake = false;
        }
        if (block.timestamp < lockTime && canStake == false) {
            canStake = true;
        }
        require(
            canStake == true,
            "Waiting Period has ended, pool is now locked"
        );
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (_amount <= 0) {
            return;
        }
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
        if (block.timestamp > unlockTime && canUnstake == false) {
            canUnstake = true;
        }
        require(canUnstake == true, "Pool is still locked");
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 reward = lockDuration * user.amount * totalRewards;
        uint256 lpSupply = pool.totalStaked * lockDuration;
        uint256 pending = reward.div(lpSupply);
        if (pending > 0) {
            safeArchaTransfer(msg.sender, pending);
        }
        if (_amount <= 0) {
            return;
        }
        if (_amount > 0) {
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            pool.totalStaked = pool.totalStaked.sub(_amount);
            user.amount = user.amount.sub(_amount);
            // Here after the last user unStakes, we check if any user forfeited their rewards.
            uint256 tStaked = pool.totalStaked.sub(pool.forfeited);
            if (tStaked == 0) {
                uint256 forfeitedRwds = archa.balanceOf(address(this));
                // if there is any forfieted reward, send it to grwothFundAddr.
                if (forfeitedRwds > 0) {
                    archa.safeTransfer(growthFundAddr, forfeitedRwds);
                }
            }
        }
        emit Unstake(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        // Here when a user leaves the pool using the emergencyWithdraw, we are meant to subtract the user.amount
        // from totalStaked, but we dont because if we subtract, it will mess up the calculation. We will subtract this
        // Later in a way that it wont mess up the reward calculation.
        pool.forfeited = pool.forfeited.add(user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
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