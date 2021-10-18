// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IReserve.sol";

contract Farming is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of MONEY Tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accMoneyPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accMoneyPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. MONEY Token share to distribute per block.
        uint256 lastRewardBlock; // Last block number that MONEY Tokens distribution occurs.
        uint256 accMoneyPerShare; // Accumulated MONEY Tokens per share, times 1e12. See below.
        uint16 depositFeeBP; // Deposit fee in basis points
    }

    // The MONEY TOKEN!
    address public money;
    // Deposit Fee address
    address public feeAddress;
    // Reserve address
    address public reserve;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    //only after this time, rewards will be fetched and ditributed to the users
    uint256 public rewardDripInterval;
    uint256 public lastRewardDripTime;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event SetFeeAddress(address indexed user, address indexed newAddress);
    event UpdatedRewardDripInterval(uint256 _rewardDripInterval);
    event SetReserveAddress(address _reserve);

    constructor(
        address _money,
        address _feeAddress,
        address _reserve,
        uint256 _rewardDripInterval
    ) public {
        money = _money;
        feeAddress = _feeAddress;
        rewardDripInterval = _rewardDripInterval;
        reserve = _reserve;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        require(
            _depositFeeBP <= 10000,
            "add: invalid deposit fee basis points"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accMoneyPerShare: 0,
                depositFeeBP: _depositFeeBP
            })
        );
    }

    // Update the given pool's MONEY allocation point and deposit fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint16 _depositFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        require(
            _depositFeeBP <= 10000,
            "set: invalid deposit fee basis points"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].depositFeeBP = _depositFeeBP;
    }

    // View function to see pending MONEY Tokens on frontend.
    function pendingMoney(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMoneyPerShare = pool.accMoneyPerShare;
        return user.amount.mul(accMoneyPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 rewards = pullRewards();
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid, rewards);
        }
    }

    function pullRewards() internal returns (uint256 rewards) {
        require(
            lastRewardDripTime.add(rewardDripInterval) >= block.timestamp,
            "REWARDS_NOT_BAKED_YET"
        );

        rewards = IReserve(reserve).withdrawRewards();
        lastRewardDripTime = block.timestamp;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid, uint256 _rewards) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 moneyReward = _rewards.mul(pool.allocPoint).div(
            totalAllocPoint
        );

        pool.accMoneyPerShare = pool.accMoneyPerShare.add(
            moneyReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MoneyFarm for MONEY allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid, 0);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accMoneyPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                safeMoneyTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            if (pool.depositFeeBP > 0) {
                uint256 depositFee = _amount.mul(pool.depositFeeBP).div(10000);
                pool.lpToken.safeTransfer(feeAddress, depositFee);
                user.amount = user.amount.add(_amount).sub(depositFee);
            } else {
                user.amount = user.amount.add(_amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accMoneyPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MoneyFarm.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid, 0);
        uint256 pending = user.amount.mul(pool.accMoneyPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            safeMoneyTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMoneyPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe money transfer function, just in case if rounding error causes pool to not have enough MONEY Tokens.
    function safeMoneyTransfer(address _to, uint256 _amount) internal {
        uint256 moneyBal = IERC20(money).balanceOf(address(this));
        bool transferSuccess = false;
        if (_amount > moneyBal) {
            transferSuccess = IERC20(money).transfer(_to, moneyBal);
        } else {
            transferSuccess = IERC20(money).transfer(_to, _amount);
        }
        require(transferSuccess, "safeMoneyTransfer: transfer failed");
    }

    function setFeeAddress(address _feeAddress) public {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        feeAddress = _feeAddress;
        emit SetFeeAddress(msg.sender, _feeAddress);
    }

    function setReserveAddress(address _reserveAddress) public onlyOwner {
        reserve = _reserveAddress;
        emit SetReserveAddress(_reserveAddress);
    }

    function updateRewardDripInterval(uint256 _rewardDripInterval)
        external
        onlyOwner
    {
        rewardDripInterval = _rewardDripInterval;
        emit UpdatedRewardDripInterval(_rewardDripInterval);
    }
}