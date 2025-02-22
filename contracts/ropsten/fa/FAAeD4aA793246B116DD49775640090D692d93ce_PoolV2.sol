// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './sPROFITV2.sol';

interface IMigratorChef {
    function migrate(IERC20 token) external returns (IERC20);
}

/** @notice PoolV2 this contract is in charge of Stability Dao
 *  Staking and Farming. Stake PROFIT tokens to earn ETH.
 *  Farming: Deposit LP tokens to earn ETH or other tokens.
 */
contract PoolV2 is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of WETHs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accWETHPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accWETHPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. WETHs to distribute per block.
        uint256 lastRewardBlock; // Last block number that WETHs distribution occurs.
        uint256 accWETHPerShare; // Accumulated WETHs per share, times 1e12. See below.
    }

    // The PoS TOKEN!
    sPROFITV2 public sProfit;
    // Dev address.
    address public devaddr;
    // ETH unlocked per block.
    uint256 public WETHPerBlock;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when ETH mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        IERC20 _PROFIT,
        sPROFITV2 _sProfit,
        address _devaddr,
        uint256 _WETHPerBlock,
        uint256 _startBlock
    ) {
        sProfit = _sProfit;
        devaddr = _devaddr;
        WETHPerBlock = _WETHPerBlock;
        startBlock = _startBlock;

        // staking pool
        poolInfo.push(
            PoolInfo({
                lpToken: _PROFIT,
                allocPoint: 1000,
                lastRewardBlock: startBlock,
                accWETHPerShare: 0
            })
        );

        totalAllocPoint = 1000;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        // require(poolInfo.length < 1, "pool already created");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accWETHPerShare: 0
            })
        );
    }

    // Update the given pool's reward token allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), 'migrate: no migrator');
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), 'migrate: bad');
        pool.lpToken = newLpToken;
    }

    // Return reward multiplier of the given _pid.
    function getMultiplier(uint256 _pid) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        return block.number.sub(pool.lastRewardBlock);
    }

    // View function to see pending WETHs on frontend.
    function pendingWETH(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accWETHPerShare = pool.accWETHPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blocks = block.number.sub(pool.lastRewardBlock);
            uint256 WETHReward = blocks
                .mul(WETHPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accWETHPerShare = accWETHPerShare.add(
                WETHReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accWETHPerShare).div(1e12).sub(user.rewardDebt);
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
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 blocks = block.number.sub(pool.lastRewardBlock);
        uint256 WETHReward = blocks.mul(WETHPerBlock).mul(pool.allocPoint).div(
            totalAllocPoint
        );
        pool.accWETHPerShare = pool.accWETHPerShare.add(
            WETHReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to Farm to earn Rewards.
    function deposit(uint256 _pid, uint256 _amount) public {
        require(_pid != 0, 'deposit tokens by staking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accWETHPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                safeWETHTransfer(_pid, msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accWETHPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from Farm.
    function withdraw(uint256 _pid, uint256 _amount) public {
        require(_pid != 0, 'withdraw tokens by unstaking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, 'withdraw: not good');
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accWETHPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            safeWETHTransfer(_pid, msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accWETHPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    /** @notice Harvest Function is a funtion that allows
     *  the user to harvest pending rewards from the Farm
     *  without withdrawing LP tokens. It simply a funtion
     *  that calls the deposit() function with zero deposit amount.
     */
    function harvest(uint256 _pid) public {
        deposit(_pid, 0);
    }

    // Stake PROFIT tokens or Other tokens to Pool
    function stake(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accWETHPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                safeWETHTransfer(_pid, msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accWETHPerShare).div(1e12);

        sProfit.mint(msg.sender, _amount);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Withdraw PROFIT tokens or Other staked tokens from STAKING.
    function unstake(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, 'withdraw: not good');
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accWETHPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            safeWETHTransfer(_pid, msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accWETHPerShare).div(1e12);

        sProfit.burn(msg.sender, _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }

    /** @notice Harvest Earnings is a funtion that allows
     *  the user to harvest pending rewards from the Staking Pool
     *  without withdrawing LP tokens. It simply a funtion
     *  that calls the stake() function with zero deposit amount.
     */
    function harvestEarnings(uint256 _pid) public {
        stake(_pid, 0);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe WETH transfer function, just in case if rounding error causes pool to not have enough WETHs.
    function safeWETHTransfer(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) internal {
        sProfit.safeWETHTransfer(_pid, _to, _amount);
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, 'dev: wut?');
        devaddr = _devaddr;
    }
}