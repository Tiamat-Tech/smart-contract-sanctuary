// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IVestable {
    function vest(
        bool vest,
        address _receiver,
        uint256 _amount
    ) external;
}

interface StakerStructs {
    /// @notice Info of each user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of GRO entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// which will determine the share of GRO token rewards the pool will get
    struct PoolInfo {
        uint256 accGroPerShare;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        IERC20 lpToken;
    }
}

interface IStaker is StakerStructs {
    function poolInfo(uint256 pid) external view returns (PoolInfo memory);

    function userInfo(uint256 pid, address account) external view returns (UserInfo memory);

    function migrateFrom(uint256[] calldata pids) external;
}

interface IStakerV1 is StakerStructs {
    function vesting() external view returns (address);

    function maxGroPerBlock() external view returns (uint256);

    function groPerBlock() external view returns (uint256);

    function totalAllocPoint() external view returns (uint256);

    function manager() external view returns (address);

    function poolLength() external view returns (uint256);

    function poolInfo(uint256 pid) external view returns (PoolInfo memory);

    function userInfo(uint256 pid, address account) external view returns (UserInfo memory);
}

contract LPTokenStaker is Ownable, StakerStructs {
    using SafeERC20 for IERC20;

    IVestable public vesting;

    /// @notice Info of each pool.
    PoolInfo[] public poolInfo;

    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    uint256 public maxGroPerBlock;
    uint256 public groPerBlock;

    address public manager;
    mapping(address => bool) public activeLpTokens;

    uint256 private constant ACC_GRO_PRECISION = 1e12;

    // !Important!Time lock contract
    address public immutable TIME_LOCK;

    event LogAddPool(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(uint256 indexed pid, uint256 lastRewardBlock, uint256 lpSupply, uint256 accGroPerShare);
    event LogDeposit(address indexed user, uint256 indexed pid, uint256 amount);
    event LogWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event LogMultiWithdraw(address indexed user, uint256[] pids, uint256[] amounts);
    event LogMultiClaim(address indexed user, uint256[] pids, uint256 amount);
    event LogClaim(address indexed user, bool vest, uint256 indexed pid, uint256 amount);
    event LogLpTokenAdded(address token);
    event LogEmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event LogNewManagment(address newManager);
    event LogMaxGroPerBlock(uint256 newMax);
    event LogGroPerBlock(uint256 newGro);
    event LogNewVester(address newVester);
    event LogSetTimelock(address timelock);

    modifier onlyTimelock() {
        require(msg.sender == TIME_LOCK, "msg.sender != timelock");
        _;
    }

    constructor(address _timelock) {
        // Setting timelock to 0x prevents migrations
        TIME_LOCK = _timelock;
        emit LogSetTimelock(_timelock);
    }

    function setVesting(address _vesting) external onlyOwner {
        vesting = IVestable(_vesting);
        emit LogNewVester(_vesting);
    }

    function setManager(address _manager) external onlyOwner {
        manager = _manager;
        emit LogNewManagment(_manager);
    }

    function setMaxGroPerBlock(uint256 _maxGroPerBlock) external onlyOwner {
        maxGroPerBlock = _maxGroPerBlock;
        emit LogMaxGroPerBlock(_maxGroPerBlock);
    }

    function setGroPerBlock(uint256 _groPerBlock) external {
        require(msg.sender == manager, "setGroPerBlock: !manager");
        require(_groPerBlock <= maxGroPerBlock, "setGroPerBlock: > maxGroPerBlock");
        groPerBlock = _groPerBlock;
        emit LogGroPerBlock(_groPerBlock);
    }

    /// @notice Returns the number of pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the manager.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    function add(uint256 allocPoint, IERC20 _lpToken) external {
        require(msg.sender == manager, "add: !manager");
        totalAllocPoint += allocPoint;

        require(!activeLpTokens[address(_lpToken)], "add: lpToken already added");
        poolInfo.push(
            PoolInfo({allocPoint: allocPoint, lastRewardBlock: block.number, accGroPerShare: 0, lpToken: _lpToken})
        );
        activeLpTokens[address(_lpToken)] = true;
        emit LogLpTokenAdded(address(_lpToken));
        emit LogAddPool(poolInfo.length - 1, allocPoint, _lpToken);
    }

    /// @notice Update the given pool's allocation point. Can only be called by the manager.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) external {
        require(msg.sender == manager, "set: !manager");
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;

        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        uint256 _totalAllocPoint = totalAllocPoint;
        require(_totalAllocPoint > 0, "updatePool: totalAllocPoint == 0");
        pool = poolInfo[pid];
        if (block.number > pool.lastRewardBlock) {
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));
            if (lpSupply > 0) {
                uint256 blocks = block.number - pool.lastRewardBlock;
                uint256 groReward = (blocks * groPerBlock * pool.allocPoint) / _totalAllocPoint;
                pool.accGroPerShare = pool.accGroPerShare + (groReward * ACC_GRO_PRECISION) / lpSupply;
            }
            pool.lastRewardBlock = block.number;
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardBlock, lpSupply, pool.accGroPerShare);
        }
    }

    /// @notice View function to see claimable GRO on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return claimable GRO reward for a given user.
    function claimable(uint256 _pid, address _user) external view returns (uint256) {
        uint256 _totalAllocPoint = totalAllocPoint;
        if (_totalAllocPoint == 0) return 0;
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accPerShare = pool.accGroPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 blocks = block.number - pool.lastRewardBlock;
            uint256 groReward = (blocks * groPerBlock * pool.allocPoint) / _totalAllocPoint;
            accPerShare = accPerShare + (groReward * ACC_GRO_PRECISION) / lpSupply;
        }
        return uint256(int256((user.amount * accPerShare) / ACC_GRO_PRECISION) - user.rewardDebt);
    }

    /// @notice Deposit LP tokens for GRO reward.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    function deposit(uint256 pid, uint256 amount) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];

        // Effects
        user.amount = user.amount + amount;
        user.rewardDebt = user.rewardDebt + int256((amount * pool.accGroPerShare) / ACC_GRO_PRECISION);

        pool.lpToken.safeTransferFrom(msg.sender, address(this), amount);

        emit LogDeposit(msg.sender, pid, amount);
    }

    /// @notice Withdraw LP tokens.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    function withdraw(uint256 pid, uint256 amount) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];

        // Effects
        user.rewardDebt = user.rewardDebt - int256((amount * pool.accGroPerShare) / ACC_GRO_PRECISION);
        user.amount = user.amount - amount;

        pool.lpToken.safeTransfer(msg.sender, amount);

        emit LogWithdraw(msg.sender, pid, amount);
    }

    function multiWithdraw(uint256[] calldata pids, uint256[] calldata amounts) public {
        for (uint256 i = 0; i < pids.length; i++) {
            uint256 pid = pids[i];
            uint256 amount = amounts[i];
            PoolInfo memory pool = updatePool(pid);
            UserInfo storage user = userInfo[pid][msg.sender];
            user.rewardDebt = user.rewardDebt - int256((amount * pool.accGroPerShare) / ACC_GRO_PRECISION);
            user.amount = user.amount - amount;
            pool.lpToken.safeTransfer(msg.sender, amount);
        }

        emit LogMultiWithdraw(msg.sender, pids, amounts);
    }

    /// @notice Claim proceeds for transaction sender. Can claim x% of the rewards imediatly, forfeiting
    ///     the remainder to the bonus contract, or add 100% as a vesting position
    /// @param vest Add to vesting position (true) or claim immeidatly (false)
    /// @param pid The index of the pool. See `poolInfo`.
    function claim(bool vest, uint256 pid) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];

        int256 accumulatedGro = int256((user.amount * pool.accGroPerShare) / ACC_GRO_PRECISION);
        uint256 pending = accumulatedGro >= user.rewardDebt ? uint256(accumulatedGro - user.rewardDebt) : 0;

        // Effects
        user.rewardDebt = accumulatedGro;

        // Interactions
        if (pending > 0) {
            vesting.vest(vest, msg.sender, pending);
        }

        emit LogClaim(msg.sender, vest, pid, pending);
    }

    function multiClaim(bool vest, uint256[] calldata pids) external {
        uint256 pending;
        for (uint256 i = 0; i < pids.length; i++) {
            PoolInfo memory pool = updatePool(pids[i]);
            UserInfo storage user = userInfo[pids[i]][msg.sender];
            int256 accumulatedGro = int256((user.amount * pool.accGroPerShare) / ACC_GRO_PRECISION);
            pending += accumulatedGro >= user.rewardDebt ? uint256(accumulatedGro - user.rewardDebt) : 0;
            user.rewardDebt = accumulatedGro;
        }

        if (pending > 0) {
            vesting.vest(vest, msg.sender, pending);
        }

        emit LogMultiClaim(msg.sender, pids, pending);
    }

    /// @notice Withdraw LP tokens and claim proceeds for transaction sender.
    /// @param vest Add to vesting position (true) or claim immeidatly (false)
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    function withdrawAndClaim(
        bool vest,
        uint256 pid,
        uint256 amount
    ) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 ua = user.amount;
        int256 accumulatedGro = int256((ua * pool.accGroPerShare) / ACC_GRO_PRECISION);
        uint256 pending = accumulatedGro >= user.rewardDebt ? uint256(accumulatedGro - user.rewardDebt) : 0;

        // Effects
        user.rewardDebt = accumulatedGro - int256((amount * pool.accGroPerShare) / ACC_GRO_PRECISION);
        user.amount = ua - amount;

        // Interactions
        if (pending > 0) {
            vesting.vest(vest, msg.sender, pending);
        }
        pool.lpToken.safeTransfer(msg.sender, amount);

        emit LogWithdraw(msg.sender, pid, amount);
        emit LogClaim(msg.sender, vest, pid, pending);
    }

    function multiWithdrawAndClaim(
        bool vest,
        uint256[] calldata pids,
        uint256[] calldata amounts
    ) public {
        uint256 pending;
        for (uint256 i = 0; i < pids.length; i++) {
            uint256 pid = pids[i];
            uint256 amount = amounts[i];
            PoolInfo memory pool = updatePool(pid);
            UserInfo storage user = userInfo[pid][msg.sender];
            uint256 ua = user.amount;
            int256 accumulatedGro = int256((ua * pool.accGroPerShare) / ACC_GRO_PRECISION);
            pending += accumulatedGro >= user.rewardDebt ? uint256(accumulatedGro - user.rewardDebt) : 0;
            user.rewardDebt = accumulatedGro - int256((amount * pool.accGroPerShare) / ACC_GRO_PRECISION);
            user.amount = ua - amount;
            pool.lpToken.safeTransfer(msg.sender, amount);
        }

        if (pending > 0) {
            vesting.vest(vest, msg.sender, pending);
        }

        emit LogMultiWithdraw(msg.sender, pids, amounts);
        emit LogMultiClaim(msg.sender, pids, pending);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    function emergencyWithdraw(uint256 pid) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;

        pool.lpToken.safeTransfer(msg.sender, amount);
        emit LogEmergencyWithdraw(msg.sender, pid, amount);
    }

    address public oldStaker;
    address public newStaker;
    mapping(address => mapping(uint256 => bool)) public userMigrated;

    event LogNewStaker(address staker);
    event LogOldStaker(address staker);
    event LogMigrate(uint256[] pids);
    event LogMigrateFrom(uint256[] pids);
    event LogMigrateUser(address indexed account, uint256[] pids);

    function setNewStaker(address staker) public onlyOwner {
        newStaker = staker;
        emit LogNewStaker(staker);
    }

    function setOldStaker(address staker) public onlyOwner {
        oldStaker = staker;
        emit LogOldStaker(staker);
    }

    function migrate(uint256[] calldata pids) external onlyTimelock {
        require(newStaker != address(0), "migrate: !newStaker");

        for (uint256 i = 0; i < pids.length; i++) {
            PoolInfo memory pi = poolInfo[pids[i]];
            uint256 amount = pi.lpToken.balanceOf(address(this));
            pi.lpToken.approve(newStaker, amount);
        }

        IStaker(newStaker).migrateFrom(pids);
        emit LogMigrate(pids);
    }

    function migrateFrom(uint256[] calldata pids) external {
        require(msg.sender == oldStaker, "migrateFrom: !oldStaker");

        uint256 _totalAllocPoint;
        IStaker staker = IStaker(oldStaker);
        for (uint256 i = 0; i < pids.length; i++) {
            PoolInfo memory pi = staker.poolInfo(pids[i]);
            require(!activeLpTokens[address(pi.lpToken)], "migrateFrom: lpToken already added");
            poolInfo.push(
                PoolInfo({
                    allocPoint: pi.allocPoint,
                    lastRewardBlock: pi.lastRewardBlock,
                    accGroPerShare: pi.accGroPerShare,
                    lpToken: pi.lpToken
                })
            );
            _totalAllocPoint += pi.allocPoint;
            uint256 amount = pi.lpToken.balanceOf(oldStaker);
            pi.lpToken.safeTransferFrom(oldStaker, address(this), amount);
            activeLpTokens[address(pi.lpToken)] = true;
        }
        totalAllocPoint += _totalAllocPoint;

        emit LogMigrateFrom(pids);
    }

    function migrateUser(address account, uint256[] calldata pids) external {
        require(oldStaker != address(0), "migrateUser: !oldStaker");

        IStaker staker = IStaker(oldStaker);
        for (uint256 i = 0; i < pids.length; i++) {
            uint256 pid = pids[i];
            require(!userMigrated[account][pid], "migrateUser: pid already done");

            UserInfo memory oldUI = staker.userInfo(pid, account);
            if (oldUI.amount > 0) {
                UserInfo storage ui = userInfo[pid][account];
                ui.amount += oldUI.amount;
                ui.rewardDebt += oldUI.rewardDebt;
                userMigrated[account][pid] = true;
            }
        }

        emit LogMigrateUser(account, pids);
    }

    bool public migratedFromV1;
    mapping(address => bool) public userMigratedFromV1;

    event LogMigrateFromV1(address staker);
    event LogUserMigrateFromV1(address indexed account, address staker);

    function migrateFromV1() external onlyOwner {
        require(!migratedFromV1, "migrateFromV1: already done");
        require(oldStaker != address(0), "migrateUser: !oldStaker");

        IStakerV1 staker = IStakerV1(oldStaker);
        vesting = IVestable(staker.vesting());
        manager = staker.manager();
        maxGroPerBlock = staker.maxGroPerBlock();
        groPerBlock = staker.groPerBlock();
        totalAllocPoint = staker.totalAllocPoint();

        uint256 len = staker.poolLength();
        for (uint256 i = 0; i < len; i++) {
            PoolInfo memory pi = staker.poolInfo(i);
            poolInfo.push(
                PoolInfo({
                    allocPoint: pi.allocPoint,
                    lastRewardBlock: pi.lastRewardBlock,
                    accGroPerShare: pi.accGroPerShare,
                    lpToken: pi.lpToken
                })
            );
            activeLpTokens[address(pi.lpToken)] = true;
        }

        migratedFromV1 = true;
        emit LogMigrateFromV1(oldStaker);
    }
}