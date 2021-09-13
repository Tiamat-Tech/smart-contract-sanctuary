// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface FreeToken is IERC20 {
    function mint(address, uint256) external;
}

contract FreeMaster is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 pendingRewards;
    }

    struct PoolInfo {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accFreePerShare;
    }

    FreeToken public immutable free;
    uint256 public freePerBlock;

    PoolInfo[] public poolInfo;
    mapping(address => bool) public addedPools;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed pid, uint256 amount);
    event SetFreePerBlock(address indexed user, uint256 freePerBlock);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    
    modifier validatePoolByPid(uint256 _pid) {
        require (_pid < poolInfo.length && _pid >= 0 , "Pool does not exist");
        _;
    }

    constructor(
        FreeToken _free,
        uint256 _freePerBlock,
        uint256 _startBlock
    ) public {
        require(address(_free) != address(0), "_free is a zero value");
        free = _free;
        freePerBlock = _freePerBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function getMultiplier(uint256 _from, uint256 _to)
        public
        pure
        returns (uint256)
    {
            return _to.sub(_from);
    }

    function add(
        uint256 _allocPoint,
        IERC20 _lpToken
    ) external onlyOwner {
        require(!addedPools[address(_lpToken)], '_lpToken already added');
        massUpdatePools();
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accFreePerShare: 0
            })
        );
        addedPools[address(_lpToken)] = true;
    }
    
    function remove(
        uint256 _pid
    ) external onlyOwner validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        require(lpSupply == 0, 'Pool not empty!');
        massUpdatePools();
        totalAllocPoint.sub(poolInfo[_pid].allocPoint);
        addedPools[address(poolInfo[_pid].lpToken)] = false;
        poolInfo[_pid] = poolInfo[poolInfo.length-1];
        poolInfo.pop();
    }

    function set(
        uint256 _pid,
        uint256 _allocPoint
    ) external onlyOwner validatePoolByPid(_pid) {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function pendingFree(uint256 _pid, address _user)
        external
        view
        validatePoolByPid(_pid)
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accFreePerShare = pool.accFreePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 freeReward = multiplier
                .mul(freePerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accFreePerShare = accFreePerShare.add(
                freeReward.mul(1e12).div(lpSupply)
            );
        }
        return
            user.amount.mul(accFreePerShare).div(1e12).sub(user.rewardDebt).add(user.pendingRewards);
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public validatePoolByPid(_pid) {
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
        uint256 freeReward = multiplier
            .mul(freePerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        free.mint(address(this), freeReward);
        pool.accFreePerShare = pool.accFreePerShare.add(
            freeReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    function deposit(uint256 _pid, uint256 _amount, bool _withdrawRewards) external validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accFreePerShare)
                .div(1e12)
                .sub(user.rewardDebt);

            if (pending > 0) {
                user.pendingRewards = user.pendingRewards.add(pending);

                if (_withdrawRewards) {
                    safeFreeTransfer(msg.sender, user.pendingRewards);
                    emit Claim(msg.sender, _pid, user.pendingRewards);
                    user.pendingRewards = 0;
                }
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accFreePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount, bool _withdrawRewards) external validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accFreePerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            user.pendingRewards = user.pendingRewards.add(pending);

            if (_withdrawRewards) {
                safeFreeTransfer(msg.sender, user.pendingRewards);
                emit Claim(msg.sender, _pid, user.pendingRewards);
                user.pendingRewards = 0;
            }
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accFreePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) external validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    }

    function claim(uint256 _pid) external validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accFreePerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0 || user.pendingRewards > 0) {
            user.pendingRewards = user.pendingRewards.add(pending);
            uint256 claimedRewards = safeFreeTransfer(msg.sender, user.pendingRewards);
            emit Claim(msg.sender, _pid, claimedRewards);
            user.pendingRewards = user.pendingRewards.sub(claimedRewards);
        }
        user.rewardDebt = user.amount.mul(pool.accFreePerShare).div(1e12);
    }

    function safeFreeTransfer(address _to, uint256 _amount) internal returns(uint256) {
        uint256 freeBal = free.balanceOf(address(this));
        if (_amount > freeBal) {
            require(free.transfer(_to, freeBal), 'transfer failed');
            return freeBal;
        } else {
            require(free.transfer(_to, _amount), 'transfer failed');
            return _amount;
        }
    }

    function setFreePerBlock(uint256 _freePerBlock) external onlyOwner {
        require(_freePerBlock > 0, "!freePerBlock-0");
        massUpdatePools();
        freePerBlock = _freePerBlock;
        emit SetFreePerBlock(msg.sender, _freePerBlock);
    }

}