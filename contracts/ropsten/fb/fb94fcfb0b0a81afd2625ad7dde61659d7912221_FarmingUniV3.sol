// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract FarmingUniV3 is
    PausableUpgradeable,
    OwnableUpgradeable,
    IERC721ReceiverUpgradeable
{
    using SafeMath for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    INonfungiblePositionManager public constant nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    struct PositionInfo {
        address owner; // Position owner
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of rewards
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (position liquidity * pool.accRewardPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws position nft to a pool. Here's what happens:
        //   1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward of the position NFT sent to his/her address.
        //   3. Position's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IUniswapV3Pool pool; // Address of uniswap v3 pool contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per block.
        uint256 lastRewardBlock; // Last block number that Rewards distribution occurs.
        uint256 accRewardPerShare; // Accumulated Rewards per share, times 1e12. See below.
        uint256 totalLiquidityAmount;
    }

    // Address of token contract
    IERC20Upgradeable token;
    // Reward tokens created per block.
    uint256 public rewardPerBlock;
    // Bonus muliplier
    uint256 public BONUS_MULTIPLIER;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP NFT.
    mapping(uint256 => mapping(uint256 => PositionInfo)) public positionInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    event Deposit(address indexed user, uint256 indexed pid, uint256 tokenId);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 tokenId);
    event Claim(address indexed user, uint256 indexed pid, uint256 tokenId);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 tokenId
    );

    function initialize(IERC20Upgradeable _token, uint256 _rewardPerBlock)
        external
        initializer
    {
        token = _token;
        rewardPerBlock = _rewardPerBlock;
        BONUS_MULTIPLIER = 1;
        totalAllocPoint = 0;
        OwnableUpgradeable.__Ownable_init();
        PausableUpgradeable.__Pausable_init();
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IUniswapV3Pool _pool,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo({
                pool: _pool,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accRewardPerShare: 0,
                totalLiquidityAmount: 0
            })
        );
    }

    // Update the given pool's reward allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint - prevAllocPoint + _allocPoint;
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return (_to - _from) * BONUS_MULTIPLIER;
    }

    // View function to see pending Rewards on frontend.
    function pendingReward(uint256 _pid, uint256 _tokenId)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        PositionInfo storage position = positionInfo[_pid][_tokenId];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        if (
            block.number > pool.lastRewardBlock &&
            pool.totalLiquidityAmount != 0
        ) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 reward = (multiplier * rewardPerBlock * pool.allocPoint) /
                totalAllocPoint;
            accRewardPerShare =
                accRewardPerShare +
                (reward * (1e12)) /
                pool.totalLiquidityAmount;
        }
        return
            (_getLiquidityPoolTokenAmount(_tokenId) * accRewardPerShare) /
            (1e12) -
            position.rewardDebt;
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
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.totalLiquidityAmount == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 reward = (multiplier * rewardPerBlock * pool.allocPoint) /
            totalAllocPoint;
        pool.accRewardPerShare =
            pool.accRewardPerShare +
            (reward * (1e12)) /
            pool.totalLiquidityAmount;
        pool.lastRewardBlock = block.number;
    }

    function _getLiquidityPoolTokenAmount(uint256 _tokenId)
        private
        view
        returns (uint128 liquidityAmount)
    {
        (, , , , , , , liquidityAmount, , , , ) = nonfungiblePositionManager
            .positions(_tokenId);
    }

    // Deposit position NFT for reward allocation.
    function deposit(uint256 _pid, uint256 _tokenId) public whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        PositionInfo storage position = positionInfo[_pid][_tokenId];
        updatePool(_pid);
        nonfungiblePositionManager.safeTransferFrom(
            address(msg.sender),
            address(this),
            _tokenId
        );
        uint256 liquidityAmount = _getLiquidityPoolTokenAmount(_tokenId);
        pool.totalLiquidityAmount = pool.totalLiquidityAmount + liquidityAmount;
        position.owner = msg.sender;
        position.rewardDebt =
            (liquidityAmount * pool.accRewardPerShare) /
            (1e12);

        emit Deposit(msg.sender, _pid, _tokenId);
    }

    // Claim rewards
    function claim(uint256 _pid, uint256 _tokenId) public whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        PositionInfo storage position = positionInfo[_pid][_tokenId];
        require(position.owner == position.owner, "invalid tokenId");

        updatePool(_pid);
        uint256 pending = (_getLiquidityPoolTokenAmount(_tokenId) *
            pool.accRewardPerShare) /
            (1e12) -
            position.rewardDebt;
        if (pending > 0) {
            token.safeTransfer(address(msg.sender), pending);
        }
        position.rewardDebt =
            (_getLiquidityPoolTokenAmount(_tokenId) * pool.accRewardPerShare) /
            (1e12);

        emit Claim(msg.sender, _pid, _tokenId);
    }

    // Withdraw position NFT
    function withdraw(uint256 _pid, uint256 _tokenId) public whenNotPaused {
        PoolInfo storage pool = poolInfo[_pid];
        PositionInfo memory position = positionInfo[_pid][_tokenId];
        require(position.owner == position.owner, "invalid tokenId");

        updatePool(_pid);
        uint256 liquidityAmount = _getLiquidityPoolTokenAmount(_tokenId);
        uint256 pending = (liquidityAmount * pool.accRewardPerShare) /
            (1e12) -
            position.rewardDebt;
        if (pending > 0) {
            token.safeTransfer(address(msg.sender), pending);
        }
        delete positionInfo[_pid][_tokenId];
        nonfungiblePositionManager.safeTransferFrom(
            address(this),
            address(msg.sender),
            _tokenId
        );
        pool.totalLiquidityAmount = pool.totalLiquidityAmount.sub(
            liquidityAmount
        );

        emit Withdraw(msg.sender, _pid, _tokenId);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid, uint256 _tokenId)
        public
        whenNotPaused
    {
        PoolInfo storage pool = poolInfo[_pid];
        delete positionInfo[_pid][_tokenId];
        nonfungiblePositionManager.safeTransferFrom(
            address(this),
            address(msg.sender),
            _tokenId
        );
        uint256 liquidityAmount = _getLiquidityPoolTokenAmount(_tokenId);
        pool.totalLiquidityAmount = pool.totalLiquidityAmount - liquidityAmount;

        emit EmergencyWithdraw(msg.sender, _pid, _tokenId);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}