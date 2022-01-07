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
contract Gabriel is Ownable {
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
        uint256 emergencyUnstaked; // To keep track of when a user left the pool using emergencyWithdraw
        uint256 rewardsInPool; // The amount reward that is in the pool. Decreases each time a user harvests their pending reward.
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
        address _growthFundAddr,
        uint256 _openTime,
        uint256 _waitPeriod,
        uint256 _lockDuration,
        uint256 _poolReward
    ) {
        archa = _archa;
        devaddr = _devaddr;
        growthFundAddr = _growthFundAddr;
        setTimeValues(_openTime, _waitPeriod, _lockDuration);
        add(archa);
        setPoolReward(_poolReward);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    // Remember to set time values before creating a pool.
    // Only create a pool when block.timestamp < openTime && block.timestamp < lockTime.
    function add(IERC20 _lpToken) public onlyOwner {
        require(lockTime > 0, "Set Time Values First");
        uint256 lastRewardBlock = lockTime;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                lastRewardBlock: lastRewardBlock,
                totalStaked: 0,
                emergencyUnstaked: 0,
                rewardsInPool: 0
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

    // Create a pool first using Add() before setting pool reward
    function setPoolReward(uint256 _value) public onlyOwner {
        require(poolInfo.length > 0, "You need to create a pool first");
        require(_value > 0, "pool reward cannot be zero");
        PoolInfo storage pool = poolInfo[0];
        totalRewards = _value * 10**9;
        // Keep track of the rewards in the pool.
        pool.rewardsInPool = _value * 10**9;
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

    // Update reward variables of a specific pool.
    function updatePool() public {
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

    }

    // Stake Archa tokens to earn rewards.
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
        updatePool();
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

    // Unstake Archa tokens.
    function unstake(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (block.timestamp > unlockTime && canUnstake == false) {
            canUnstake = true;
        }
        require(canUnstake == true, "Pool is still locked");
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        uint256 reward = lockDuration * user.amount * totalRewards;
        uint256 lpSupply = pool.totalStaked * lockDuration;
        uint256 pending = reward.div(lpSupply);
        if (pending > 0) {
            safeArchaTransfer(msg.sender, pending);
            // To Know the actual amount of reward remaining in the pool
            pool.rewardsInPool = pool.rewardsInPool.sub(pending);
        }
        if (_amount <= 0) {
            return;
        }
        if (_amount > 0) {
            // Transfer the amount the user unstaked to the user's wallet
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            // Calculate the total amount of rewards that were forfeited
            uint256 forfeitedRwds = (pool.emergencyUnstaked * lockDuration * totalRewards) / (pool.totalStaked * lockDuration);

            uint256 staked = pool.totalStaked;
            staked = staked.sub(_amount);
            // decrease the user.amount after unstake successful.
            user.amount = user.amount.sub(_amount);
            // After the last user unStakes, we check if any user forfeited their rewards.
            uint256 tStaked = staked.sub(pool.emergencyUnstaked); // Here we finally subtract emergencyUnstaked from totalStaked to get the actual total staked.
            if (tStaked == 0) {
                // Calculate the LOR.
                uint256 poolBal = pool.lpToken.balanceOf(address(this));
                // min = tStaked + pool.rewardsInPool + forfeitedRwds
                uint256 min = tStaked + pool.rewardsInPool + forfeitedRwds;
                if (poolBal > min) {
                    /** LOR is the reflections that will enter this contract address due to the fact that the contract holds ARCHA tokens
                     *  The Important amounts that are in the pool are:
                     *  totalStaked --> The total amount of lpTokens sent to the pool
                     *  rewardsInPool --> The amount of tokens sent to the pool that will be used to pay stakers once the unstake
                     *  forfeitedRewards --> Total amount of all forfeitedRewards
                     *  Note: After adding all these amounts together, and subtracting from poolBal, any tokens left shhould be LOR.
                     */
                    uint256 LOR = poolBal.sub(min);
                    if (LOR > 0) {
                        // Split LOR
                        uint256 half = LOR.div(2);
                        uint256 otherHalf = LOR.sub(half);
                        // Transfer Half to devaddr, for code maintenance
                        pool.lpToken.safeTransfer(devaddr, half);
                        // Transfer otherHalf to growthFundAddr, to store funds for future growth of this project
                        pool.lpToken.safeTransfer(growthFundAddr, otherHalf);
                    }
                }
                // If any user forfeited their rewards, it will remain in the pool after LOR is sent to devaddr & growthFundAddr
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
        /** Here when a user leaves the pool using the emergencyWithdraw, we are meant to subtract the user.amount
         * from totalStaked, but we dont because if we subtract, it will mess up the calculation. We will subtract this
         * Later in a way that it wont mess up the reward calculation.
         */
        pool.emergencyUnstaked = pool.emergencyUnstaked.add(user.amount);
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