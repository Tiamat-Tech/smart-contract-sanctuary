// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MonoToken.sol";
import "./MockLpToken.sol";
import "hardhat/console.sol";

// MonoswapStaking is the master of Mono. He can make Mono and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once MONO is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MonoswapStaking is Ownable, ERC1155Holder {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 lastRewardBlock; // Last reward block.
        uint256 oldReward; // Old pool's reward. 
        //
        // We do some fancy math here. Basically, any point in time, the amount of MONOs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accMonoPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accMonoPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC1155 lpToken; // Address of LP token contract.
        uint256 lpTokenId; // Id of LP token.
        uint256 stakedAmount; // Total LP tokens that the pool has.
        uint256 allocPoint; // How many allocation points assigned to this pool. MONOs to distribute per block.
        uint256 lastRewardBlock; // Last block number that MONOs distribution occurs.
        uint256 prevAccMonoPerShare; // Prev Period Accumulated MONOs per share, times 1e12.
        uint256 accMonoPerShare; // Accumulated MONOs per share, times 1e12. See below.
        address[] users; // List of user address.
        uint256 usersLen; // Length of user addresses.
        bool bActive; 
    }
    // The MONO TOKEN!
    MonoToken public mono;
    // MONO tokens created per reward period.
    uint256 public monoPerPeriod;
    // Block numbers per reward period.
    uint256 public blockPerPeriod;
    // Decay rate per period
    uint256 public decay; // times 1e12
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // Current Period.
    uint256 public currentPeriod;
    mapping(uint256 => uint256) public ratios;
    uint256 public startBlock;
    
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        MonoToken _mono,
        uint256 _monoPerPeriod,
        uint256 _blockPerPeriod,
        uint256 _decay
    ) public {
        mono = _mono;
        monoPerPeriod = _monoPerPeriod;
        blockPerPeriod = _blockPerPeriod;
        decay = _decay;
        startBlock = block.number;
        currentPeriod = 0;
        ratios[currentPeriod] = 1e12;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC1155 _lpToken,
        uint256 _lpTokenId,
        bool _withUpdate
    ) public onlyOwner {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            require(!(pool.bActive && pool.lpToken == _lpToken && pool.lpTokenId == _lpTokenId), "add: same lp token with same id");
        }
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                lpTokenId: _lpTokenId,
                stakedAmount: 0,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                prevAccMonoPerShare: 0,
                accMonoPerShare: 0,
                users: new address[](0),
                usersLen: 0,
                bActive: true
            })
        );
    }

    // Update the given pool's MONO allocation point. Can only be called by the owner.
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

    // Return reward periods over the given _from to _to block.
    function getPeriods(uint256 _from, uint256 _to)
        public
        view
        returns (uint256, uint256)
    {
        return (_from.sub(startBlock).div(blockPerPeriod),
            _to.sub(startBlock).div(blockPerPeriod));
    }

    function calcReward(uint256 _startPeriod, uint256 _endPeriod, uint256 _ratio, uint256 _allocPoint)
        public
        view
        returns (uint256)
    {
        uint256 multiplier = 0;
        while (_startPeriod < _endPeriod) {
            multiplier = multiplier.add(_ratio);
            _startPeriod += 1;
            _ratio = _startPeriod <= currentPeriod ? ratios[_startPeriod] : _ratio.mul(decay).div(1e12);
        }
        return multiplier.mul(monoPerPeriod).mul(_allocPoint).div(totalAllocPoint);
    }

    // View function to see pending MONOs on frontend.
    function pendingMono(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMonoPerShare = pool.accMonoPerShare;
        uint256 stakedAmount = pool.stakedAmount;
        if (block.number >= pool.lastRewardBlock && stakedAmount != 0 && user.amount != 0) {
            if (pool.bActive == true) {
                uint256 startPeriod;
                uint256 endPeriod;
                (startPeriod, endPeriod) = getPeriods(pool.lastRewardBlock, block.number);
                uint256 index = currentPeriod;
                uint256 ratio = ratios[index];
                while (index < startPeriod) {
                    ratio = ratio.mul(decay).div(1e12);
                    index += 1;
                }
                if (user.lastRewardBlock.sub(startBlock) % blockPerPeriod > block.number.sub(startBlock) % blockPerPeriod) {
                    endPeriod -= 1;
                }
                uint256 monoReward = calcReward(startPeriod, endPeriod, ratio, pool.allocPoint);
                if (user.oldReward > 0) {
                    monoReward = monoReward.add(user.oldReward.mul(stakedAmount).div(user.amount).mul(1e12));
                }
                accMonoPerShare = accMonoPerShare.add(
                    monoReward.div(stakedAmount)
                );
            } else {
                if (user.lastRewardBlock.sub(startBlock) % blockPerPeriod > pool.lastRewardBlock.sub(startBlock) % blockPerPeriod) {
                    accMonoPerShare = pool.prevAccMonoPerShare;
                }
            }
        }
        return user.amount.mul(accMonoPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            if (pool.bActive)
                updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 stakedAmount = pool.stakedAmount;
        if (stakedAmount == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 startPeriod;
        uint256 endPeriod;
        (startPeriod, endPeriod) = getPeriods(pool.lastRewardBlock, block.number);
        uint256 ratio = ratios[currentPeriod];
        while (currentPeriod < endPeriod) {
            ratio = ratio.mul(decay).div(1e12);
            currentPeriod += 1;
            ratios[currentPeriod] = ratio;
        }
        uint256 prevMonoReward = 0;
        uint256 monoReward = 0;
        if (startPeriod < endPeriod) {
            prevMonoReward = calcReward(startPeriod, endPeriod-1, ratios[startPeriod], pool.allocPoint);
            monoReward = prevMonoReward.add(ratios[endPeriod-1].mul(monoPerPeriod).mul(pool.allocPoint).div(totalAllocPoint));
        }
        mono.mint(address(this), monoReward.div(1e12));
        pool.prevAccMonoPerShare = pool.accMonoPerShare.add(
            prevMonoReward.div(stakedAmount)
        );
        pool.accMonoPerShare = pool.accMonoPerShare.add(
            monoReward.div(stakedAmount)
        );
        pool.lastRewardBlock = block.number;
    }

    // Stop pool.
    function stopPool(uint256 _pid) public onlyOwner {
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        pool.bActive = false;
        totalAllocPoint = totalAllocPoint.sub(pool.allocPoint);
    }

    // Migrate pool, move lp tokens and rewards from the old pool. 
    function migratePool(uint256 _oldPid, uint256 _newPid) public {
        PoolInfo storage oldPool = poolInfo[_oldPid];
        PoolInfo storage newPool = poolInfo[_newPid];
        require(oldPool.bActive == false && newPool.bActive == true, "migrate: wrong pools");
        require(oldPool.lpToken == newPool.lpToken && oldPool.lpTokenId == newPool.lpTokenId, "migrate: different token pools");
        updatePool(_newPid);
        uint256 len = newPool.usersLen;
        for (uint256 uid = 0; uid < len; uid++) { 
            uint256 newAccMonoPerShare = newPool.accMonoPerShare;    
            UserInfo storage newUser = userInfo[_newPid][newPool.users[uid]];
            if (newUser.lastRewardBlock.sub(startBlock) % blockPerPeriod > newPool.lastRewardBlock.sub(startBlock) % blockPerPeriod) {
                newAccMonoPerShare = newPool.prevAccMonoPerShare;
            }
            newUser.oldReward = newUser.oldReward.add(newUser.amount.mul(newAccMonoPerShare).div(1e12).sub(newUser.rewardDebt));
            newUser.lastRewardBlock = block.number;
            newUser.rewardDebt = newUser.amount.mul(newPool.accMonoPerShare).div(1e12);
        }
        len = oldPool.usersLen;
        uint256 newAccMonoPerShare = newPool.accMonoPerShare;
        for (uint256 uid = 0; uid < len; uid++) { 
            uint256 oldAccMonoPerShare = oldPool.accMonoPerShare;
            UserInfo storage oldUser = userInfo[_oldPid][oldPool.users[uid]];
            UserInfo storage newUser = userInfo[_newPid][oldPool.users[uid]];
            newPool.stakedAmount = newPool.stakedAmount.add(oldUser.amount);
            if (newUser.amount > 0) {
                newPool.users.push(oldPool.users[uid]);
                newPool.usersLen++;
            }
            newUser.amount = newUser.amount.add(oldUser.amount);
            if (oldUser.lastRewardBlock.sub(startBlock) % blockPerPeriod > oldPool.lastRewardBlock.sub(startBlock) % blockPerPeriod) {
                oldAccMonoPerShare = oldPool.prevAccMonoPerShare;
            }
            newUser.oldReward = newUser.oldReward.add(oldUser.amount.mul(oldAccMonoPerShare).div(1e12).sub(oldUser.rewardDebt));
            newUser.rewardDebt = newUser.amount.mul(newAccMonoPerShare).div(1e12);
            newUser.lastRewardBlock = block.number;
            oldUser.amount = 0;
        }
        oldPool.users = new address[](0);
        oldPool.stakedAmount = 0;
    }

    // Deposit LP tokens to MonoswapStaking for MONO allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pool.bActive == true, "deposit: stopped pool");
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 accMonoPerShare = pool.accMonoPerShare;
            if (user.lastRewardBlock.sub(startBlock) % blockPerPeriod > block.number.sub(startBlock) % blockPerPeriod) {
                accMonoPerShare = pool.prevAccMonoPerShare;
            }
            uint256 pending = user.amount.mul(accMonoPerShare).div(1e12) > user.rewardDebt ?
                user.amount.mul(accMonoPerShare).div(1e12).sub(
                    user.rewardDebt
                ) : 0;
            if (user.oldReward > 0) {
                pending = pending.add(user.oldReward);
                user.oldReward = 0;
            }
            if (pending > 0)
                safeMonoTransfer(msg.sender, pending);
        } else {
            pool.users.push(msg.sender);
            pool.usersLen++;
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            pool.lpTokenId,
            _amount,
            ""
        );
        pool.stakedAmount = pool.stakedAmount.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accMonoPerShare).div(1e12);
        user.lastRewardBlock = block.number;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MonoswapStaking.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        if (pool.bActive == true) {
            updatePool(_pid);
        }
        uint256 currentRewardBlock = pool.bActive == true ? block.number : pool.lastRewardBlock;
        uint256 accMonoPerShare = pool.accMonoPerShare;
        if (user.lastRewardBlock.sub(startBlock) % blockPerPeriod > currentRewardBlock.sub(startBlock) % blockPerPeriod) {
            accMonoPerShare = pool.prevAccMonoPerShare;
        }
        uint256 pending = user.amount.mul(accMonoPerShare).div(1e12) > user.rewardDebt ?
                user.amount.mul(accMonoPerShare).div(1e12).sub(
                    user.rewardDebt
                ) : 0;
        if (user.oldReward > 0) {
            
            pending = pending.add(user.oldReward);
            user.oldReward = 0;
        }
        if (pending > 0)
            safeMonoTransfer(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accMonoPerShare).div(1e12);
        user.lastRewardBlock = block.number;
        if (user.amount == 0) {
            uint256 len = pool.usersLen;
            for (uint256 uid = 0; uid < len; uid++) {
                if (pool.users[uid] == msg.sender) {
                    pool.users[uid] = pool.users[len-1];
                    pool.usersLen--;
                    break;
                }
            }
        }
        pool.stakedAmount = pool.stakedAmount.sub(_amount);
        pool.lpToken.safeTransferFrom(
            address(this),
            address(msg.sender),
            pool.lpTokenId,
            _amount,
            ""
        );
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransferFrom(
            address(this),
            address(msg.sender),
            pool.lpTokenId,
            user.amount,
            ""
        );
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe mono transfer function, just in case if rounding error causes pool to not have enough MONOs.
    function safeMonoTransfer(address _to, uint256 _amount) internal {
        uint256 monoBal = mono.balanceOf(address(this));
        if (_amount > monoBal) {
            mono.transfer(_to, monoBal);
        } else {
            mono.transfer(_to, _amount);
        }
    }
}