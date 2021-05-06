// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./ILiquidityProvider.sol";
import "./IMasterChef.sol";
import "./ICombMaster.sol";
import "hardhat/console.sol";

interface IMigratorChef {
    function migrate(IERC20 token) external returns (IERC20);
}

contract CombMaster is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. COMBs to distribute per block.
        uint256 lastRewardBlockTimestamp; // Last block number that COMBs distribution occurs.
        uint256 accCombPerShare; // Accumulated COMBs per share, times 1e12. See below.
    }

    // The COMB TOKEN!
    IERC20 public comb;
    IMasterChef private oldMasterchef;
    ILiquidityProvider private liquidityProvider;
    // COMB tokens created per second.
    uint256 public rewardPerSecond;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    mapping(address => bool) public lpTokenExistsInPool;
    mapping(address => bool) public isMigrated;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    // The block number when COMB mining starts.
    uint256 public startTimestamp;
    uint256 private _apiID;

    IMigratorChef public migrator;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    fallback() external payable {}

    receive() external payable {}

    function initialize(IERC20 _comb, address payable _oldMasterchef)
        public
        initializer
    {
        OwnableUpgradeable.__Ownable_init();
        comb = _comb;
        oldMasterchef = IMasterChef(_oldMasterchef);

        rewardPerSecond = 2e14;
        startTimestamp = block.timestamp;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function setLiquidityProvider(ILiquidityProvider _liquidityProvider)
        external
        onlyOwner
    {
        liquidityProvider = _liquidityProvider;
    }

    function setApi(uint256 _id) external onlyOwner {
        _apiID = _id;
    }
    // Add a new lp to the pool. Can only be called by the owner.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        require(
            !lpTokenExistsInPool[address(_lpToken)],
            "MasterCheif: LP Token Address already exists in pool"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlockTimestamp =
            block.timestamp > startTimestamp ? block.timestamp : startTimestamp;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlockTimestamp: lastRewardBlockTimestamp,
                accCombPerShare: 0
            })
        );
        lpTokenExistsInPool[address(_lpToken)] = true;
    }

    function updateLpTokenExists(address _lpTokenAddr, bool _isExists)
        external
        onlyOwner
    {
        lpTokenExistsInPool[_lpTokenAddr] = _isExists;
    }

    // Update the given pool's COMB allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function rewardOnBlock(uint256 _from, uint256 _to)
        public
        view
        returns (uint256 _reward)
    {
        _reward = (_to - _from) * rewardPerSecond;
    }

    // View function to see pending COMBs on frontend.
    function pendingComb(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accCombPerShare = pool.accCombPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardBlockTimestamp && lpSupply != 0) {
            uint256 pendingReward =
                rewardOnBlock(pool.lastRewardBlockTimestamp, block.timestamp);
            uint256 combReward =
                (pendingReward * pool.allocPoint) / totalAllocPoint;
            accCombPerShare = accCombPerShare + (combReward * 1e12) / lpSupply;
        }
        return (user.amount * accCombPerShare) / 1e12 - user.rewardDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardBlockTimestamp) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlockTimestamp = block.timestamp;
            return;
        }
        uint256 pendingReward = rewardOnBlock(pool.lastRewardBlockTimestamp, block.timestamp);
        uint256 combReward =
            (pendingReward * pool.allocPoint) / totalAllocPoint;
        pool.accCombPerShare =
            pool.accCombPerShare +
            (combReward * 1e12) /
            lpSupply;
        pool.lastRewardBlockTimestamp = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for COMB allocation.
    function _deposit(uint256 _pid, uint256 _amount) private {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.amount > 0) {
            uint256 pending =
                (user.amount * pool.accCombPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                safeCombTransfer(msg.sender, pending);
            }
        }
        user.amount = user.amount + _amount;
        user.rewardDebt = (user.amount * pool.accCombPerShare) / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Deposit LP tokens to MasterChef for COMB allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending =
                (user.amount * pool.accCombPerShare) / 1e12 - user.rewardDebt;
            if (pending > 0) {
                safeCombTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount + _amount;
        }
        user.rewardDebt = (user.amount * pool.accCombPerShare) / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    function depositETH(
        uint256 _getAmountsIn,
        uint256 _amountTokenMin,
        uint256 _amountETHMin,
        uint256 _poolId,
        uint256 _deadline
    ) public payable {
        require(msg.value > 1, "Amount can not be 0");
        updatePool(_poolId);

        IUniswapV2Pair lptoken =
            IUniswapV2Pair(address(poolInfo[_poolId].lpToken));

        uint256 lptokens =
            liquidityProvider.addLiquidityETHByPair{value: msg.value}(
                lptoken,
                address(this),
                _getAmountsIn,
                _amountTokenMin,
                _amountETHMin,
                _deadline,
                0
            );
        _deposit(_poolId, lptokens);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending =
            (user.amount * pool.accCombPerShare) / 1e12 - user.rewardDebt;
        if (pending > 0) {
            safeCombTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount - _amount;
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = (user.amount * pool.accCombPerShare) / 1e12;
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

    // Safe comb transfer function, just in case if rounding error causes pool to not have enough COMBs.
    function safeCombTransfer(address _to, uint256 _amount) internal {
        uint256 combBal = comb.balanceOf(address(this));
        if (_amount > combBal) {
            comb.transfer(_to, combBal);
        } else {
            comb.transfer(_to, _amount);
        }
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(
            !lpTokenExistsInPool[address(newLpToken)],
            "CombMaster: New LP Token Address already exists in pool"
        );
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
        lpTokenExistsInPool[address(newLpToken)] = true;
    }

    function speedStake(
        uint256 _pid,
        uint256 _amountAMin,
        uint256 _amountBMin,
        uint256 _minAmountOutA,
        uint256 _minAmountOutB,
        uint256 _deadline
    ) public payable returns (uint256) {
        (address router, , ) = liquidityProvider.apis(_apiID);
        require(
            router != address(0),
            "CombMaster: Exchange does not set yet"
        );
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lp;

        updatePool(_pid);

        IUniswapV2Pair lpToken = IUniswapV2Pair(address(pool.lpToken));
        if (
            (lpToken.token0() == IUniswapV2Router02(router).WETH()) ||
            ((lpToken.token1() == IUniswapV2Router02(router).WETH()))
        ) {
            lp = liquidityProvider.addLiquidityETHByPair{value: msg.value}(
                lpToken,
                address(this),
                _amountAMin,
                _amountBMin,
                _minAmountOutA,
                _deadline,
                _apiID
            );
        } else {
            lp = liquidityProvider.addLiquidityByPair{value: msg.value}(
                lpToken,
                _amountAMin,
                _amountBMin,
                _minAmountOutA,
                _minAmountOutB,
                address(this),
                _deadline,
                _apiID
            );
        }

        _deposit(_pid, lp);
    }

    function setPools(
        IERC20 _lpToken,
        uint256 _allocPoint,
        uint256 _lastRewardBlock,
        uint256 _accCombPerShare
    ) public {
        require(
            msg.sender == address(migrator),
            "CombMaster: Only migrator can call"
        );
        poolInfo.push(
            PoolInfo(
                IERC20(_lpToken),
                _allocPoint,
                _lastRewardBlock,
                _accCombPerShare
            )
        );
    }

    function setUser(
        uint256 _pid,
        address _user,
        uint256 _amount,
        uint256 _rewardDebt
    ) public {
        require(poolInfo.length != 0, "CombMaster: Pools must be migrated");
        userInfo[_pid][_user] = UserInfo(_amount, _rewardDebt);
    }

}