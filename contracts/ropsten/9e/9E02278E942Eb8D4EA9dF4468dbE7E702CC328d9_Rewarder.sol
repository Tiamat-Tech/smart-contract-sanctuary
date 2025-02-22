// SPDX-License-Identifier:  MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

interface IRewarder {
    function onReward(
        uint256 pid,
        address user,
        address recipient,
        uint256 rewardAmount,
        uint256 newLpAmount
    ) external;

    function pendingTokens(
        uint256 pid,
        address user,
        uint256 rewardAmount
    ) external view returns (IERC20[] memory, uint256[] memory);
}

interface IFarm {
    function lpToken(uint256 _pid) external view returns (IERC20);
}

contract Rewarder is Ownable, IRewarder {
    using SafeERC20 for IERC20;

    // Reward Token --- LFI.
    IERC20 private rewardToken;

    // User Info Struct
    struct UserInfo {
        uint256 amount; // How many LP Tokens the user has provided
        uint256 rewardDebt; // Amount of LFI entitled to users but is pending to be distributed
    }
    // Pool Info struct
    struct PoolInfo {
        uint256 accRewardPerShare; // Accumulated LFI per share.
        uint256 lastRewardTime; // Last timeStamp that LFI Distribution occured.
        uint256 allocPoint; //Allocation points assigned to this pool.
    }

    //Info of every pool
    mapping(uint256 => PoolInfo) public poolInfo;

    uint256[] public poolIds; // List of Pool IDs

    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 totalAllocPoint;

    uint256 public rewardPerSecond;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    address private LFI_FARM; 

    event LogOnReward(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        address indexed to
    );
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(
        uint256 indexed pid,
        uint256 lastRewardTime,
        uint256 lpSupply,
        uint256 accRewardPerShare
    );
    event LogRewardPerSecond(uint256 rewardPerSecond);
    event LogInit();

    constructor(
        IERC20 _rewardToken,
        uint256 _rewardPerSecond, //5
        address _LFI_FARM
    ) {
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        LFI_FARM = _LFI_FARM;
    }

    function onReward(
        uint256 pid,
        address _user,
        address to,
        uint256,
        uint256 lpToken
    ) external override onlyMCV2 {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][_user];
        uint256 pending;
        if (user.amount > 0) {
            pending =
                (user.amount * pool.accRewardPerShare) /
                ACC_TOKEN_PRECISION -
                user.rewardDebt;
            rewardToken.safeTransfer(to, pending);
        }
        user.amount = lpToken;
        user.rewardDebt =
            (lpToken * pool.accRewardPerShare) /
            ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, pid, pending, to);
    }

    function pendingTokens(
        uint256 pid,
        address user,
        uint256
    )
        external
        view
        override
        returns (IERC20[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        IERC20[] memory _rewardTokens = new IERC20[](1);
        _rewardTokens[0] = (rewardToken);
        uint256[] memory _rewardAmounts = new uint256[](1);
        _rewardAmounts[0] = pendingToken(pid, user);
        return (_rewardTokens, _rewardAmounts);
    }

    /// @notice Sets the reward per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of Sushi to be distributed per second.
    function setRewardPerSecond(uint256 _rewardPerSecond) public onlyOwner {
        rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }

    modifier onlyMCV2() {
        require(msg.sender == LFI_FARM, "Only MCV2 can call this function.");
        _;
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolIds.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _pid Pid on MCV2
    function add(uint256 allocPoint, uint256 _pid) public onlyOwner {
        require(poolInfo[_pid].lastRewardTime == 0, "Pool already exists");
        uint256 lastRewardTime = block.timestamp;
        totalAllocPoint += allocPoint;

        poolInfo[_pid] = PoolInfo({
            allocPoint: allocPoint,
            lastRewardTime: lastRewardTime,
            accRewardPerShare: 0
        });
        poolIds.push(_pid);
        emit LogPoolAddition(_pid, allocPoint);
    }

    /// @notice Update the given pool's reward allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) public onlyOwner {
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending reward for a given user.
    function pendingToken(uint256 _pid, address _user)
        public
        view
        returns (uint256 pending)
    {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = IFarm(LFI_FARM).lpToken(_pid).balanceOf(
            LFI_FARM
        );
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 time = block.timestamp - pool.lastRewardTime;
            uint256 rewardAmount = (time * rewardPerSecond * pool.allocPoint) /
                totalAllocPoint;
            accRewardPerShare +=
                (rewardAmount * ACC_TOKEN_PRECISION) /
                lpSupply;
        }
        pending =
            (user.amount * accRewardPerShare) /
            ACC_TOKEN_PRECISION -
            user.rewardDebt;
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
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint256 lpSupply = IFarm(LFI_FARM).lpToken(pid).balanceOf(
                LFI_FARM
            );
            if (lpSupply > 0) {
                uint256 time = block.timestamp - pool.lastRewardTime;
                uint256 rewardAmount = (time *
                    rewardPerSecond *
                    pool.allocPoint) / totalAllocPoint;
                pool.accRewardPerShare =
                    pool.accRewardPerShare +
                    (rewardAmount * ACC_TOKEN_PRECISION) /
                    lpSupply;
            }
            pool.lastRewardTime = block.timestamp;
            poolInfo[pid] = pool;
            emit LogUpdatePool(
                pid,
                pool.lastRewardTime,
                lpSupply,
                pool.accRewardPerShare
            );
        }
    }
}