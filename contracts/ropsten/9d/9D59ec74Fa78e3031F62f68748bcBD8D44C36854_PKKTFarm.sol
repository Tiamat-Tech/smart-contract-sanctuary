// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PKKTToken.sol";

// MasterChef is the master of PKKT. He can make PKKT and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once PKKT is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract PKKTFarm is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint pendingReward;// Reward but not harvest
        //
        // We do some fancy math here. Basically, any point in time, the amount of PKKTs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accPKKTPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accPKKTPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. PKKTs to distribute per block.
        uint256 lastRewardBlock; // Last block number that SUSHIs distribution occurs.
        uint256 accPKKTPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
    }
    // The PKKT TOKEN!
    PKKTToken public pkkt;
    // Dev address.
    address public devaddr;
    // Block number when bonus PKKT period ends.
    uint256 public bonusEndBlock;
    // PKKT tokens created per block.
    uint256 public pkktPerBlock;
    // Bonus muliplier for early PKKT makers.
    uint256 public constant BONUS_MULTIPLIER = 10;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when PKKT mining starts.
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event HarvestReward(
        address indexed user,
         uint256 indexed pid,
          uint256 amount
    );

    constructor(
        PKKTToken _pkkt,
        address _devaddr,
        uint256 _pkktPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) public {
        pkkt = _pkkt;
        devaddr = _devaddr;
        pkktPerBlock = _pkktPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accPKKTPerShare: 0
            })
        );
    }

    // Update the given pool's PKKT allocation point. Can only be called by the owner.
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

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending PKKTs on frontend.
    function pendingPKKT(uint256 _pid, address _user)
        external
        view
        returns (uint256 )
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accPKKTPerShare = pool.accPKKTPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 pkktReward =
                multiplier.mul(pkktPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accPKKTPerShare = accPKKTPerShare.add(
                pkktReward.mul(1e12).div(lpSupply)
            );
        }
        return user.pendingReward.add(user.amount.mul(accPKKTPerShare).div(1e12).sub(user.rewardDebt));
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
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 pkktReward =
            multiplier.mul(pkktPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        pool.accPKKTPerShare = pool.accPKKTPerShare.add(
            pkktReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for PKKT allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending =
                user.amount.mul(pool.accPKKTPerShare).div(1e12).sub(
                    user.rewardDebt
                );
        user.pendingReward = user.pendingReward.add(pending);
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accPKKTPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from Pool.
    function withdraw(uint256 _pid, uint256 _amount, bool harvestReward) public {
         PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        if (harvestReward || user.amount == _amount) {
            harvest(_pid); 
        }
        else { 
            updatePool(_pid);
            uint256 pending = user.amount.mul(pool.accPKKTPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) { 
               user.pendingReward = user.pendingReward.add(pending);
            } 
        }
        user.amount = user.amount.sub(_amount); 
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        user.rewardDebt = user.amount.mul(pool.accPKKTPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
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

    //Harvest proceeds for transaction sender to msg.sender
    function harvest(uint256 _pid) public {
       updatePool(_pid); 
       PoolInfo storage pool = poolInfo[_pid];
       UserInfo storage user = userInfo[_pid][msg.sender];  
       uint256 pendingReward = user.pendingReward;
       uint256 totalPending = 
                            user.amount.mul(pool.accPKKTPerShare)
                                        .div(1e12)
                                        .sub(user.rewardDebt)
                                        .add(pendingReward); 
       user.pendingReward = 0;
       if (totalPending > 0) {
            pkkt.mint(devaddr, totalPending.div(10));
            pkkt.mint(address(this), totalPending);
            safePKKTTransfer(msg.sender, totalPending); 
        }
        user.rewardDebt = user.amount.mul(pool.accPKKTPerShare).div(1e12);
        emit HarvestReward(msg.sender, _pid, totalPending);
    }

    // Safe pkkt transfer function, just in case if rounding error causes pool to not have enough PKKTs.
    function safePKKTTransfer(address _to, uint256 _amount) internal {
        uint256 pkktBal = pkkt.balanceOf(address(this));
        if (_amount > pkktBal) {
            pkkt.transfer(_to, pkktBal);
        } else {
            pkkt.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}