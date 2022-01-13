// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract StakingContract is OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardAPY; // Reward debt. See explanation below.
        uint256 endBlock;
        uint256 startBlock;
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20Upgradeable lpToken; // Address of LP token contract.
        uint256 rewardAPY;
        uint256 lockDays;
        uint256 startBlock;
        uint256 bonusEndBlock;
        uint256 maxStaking;
        uint256 totalStaked;
    }

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => mapping(uint256 => UserInfo)) public userInfo;

    uint256 internal constant SECONDS_PER_YEAR = 365 days;

    event Deposit(address indexed user, uint256 amount, address token);
    event Withdraw(address indexed user, uint256 amount, address token);
    event EmergencyWithdraw(
        address indexed user,
        uint256 amount,
        address token
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Ownable_init();
    }

    function addPool(
        address _syrup,
        uint256 _rewardAPY,
        uint256 _lockDays,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _maxStaking
    ) public onlyOwner {
        PoolInfo memory pool = PoolInfo({
            lpToken: IERC20Upgradeable(_syrup),
            rewardAPY: _rewardAPY,
            lockDays: _lockDays,
            startBlock: _startBlock,
            bonusEndBlock: _bonusEndBlock,
            maxStaking: _maxStaking,
            totalStaked: 0
        });
        poolInfo.push(pool);
    }

    function stopReward(uint256 _id) public onlyOwner {
        poolInfo[_id].bonusEndBlock = block.timestamp;
    }

    function changeStartBlock(uint256 _startBlock, uint256 _id)
        public
        onlyOwner
    {
        poolInfo[_id].startBlock = _startBlock;
    }

    function changeEndBlock(uint256 _bonusEndBlock, uint256 _id)
        public
        onlyOwner
    {
        require(
            _bonusEndBlock >= block.timestamp,
            "should be later than current time"
        );
        poolInfo[_id].bonusEndBlock = _bonusEndBlock;
    }

    function changeRewardAYP(uint256 _rewardAPY, uint256 _id) public onlyOwner {
        poolInfo[_id].rewardAPY = _rewardAPY;
    }

    function changeMaxStaking(uint256 _maxStaking, uint256 _id)
        public
        onlyOwner
    {
        poolInfo[_id].maxStaking = _maxStaking;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to,
        uint256 _id
    ) public view returns (uint256) {
        PoolInfo storage pool = poolInfo[_id];
        if (_to <= pool.bonusEndBlock) {
            return _to.sub(_from);
        } else if (_from >= pool.bonusEndBlock) {
            return 0;
        } else {
            return pool.bonusEndBlock.sub(_from);
        }
    }

    // View function to see pending Reward on frontend.
    function pendingReward(address _user, uint256 _id)
        external
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_user][_id];
        PoolInfo storage pool = poolInfo[_id];
        uint256 lpSupply = pool.totalStaked;

        if (block.timestamp > user.startBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                user.startBlock,
                block.timestamp,
                _id
            );
            return
                user.amount.mul(multiplier).mul(pool.rewardAPY).div(100).div(
                    SECONDS_PER_YEAR
                );
        }

        return 0;
    }

    // Stake SYRUP tokens to StakingPool
    function deposit(uint256 _amount, uint256 _id) public {
        PoolInfo storage pool = poolInfo[_id];
        UserInfo storage user = userInfo[msg.sender][_id];

        require(_amount > 0, "staking amount should be greater than zero");
        require(_amount <= pool.maxStaking, "exceed max stake");
        require(user.amount == 0, "already staked some tokens");
        require(block.timestamp < pool.bonusEndBlock, "Pool has been closed");
        require(block.timestamp > pool.startBlock, "Pool has not started yet");

        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = _amount;
            user.startBlock = block.timestamp;
            user.endBlock = block.timestamp + pool.lockDays * 1 days;
            user.rewardAPY = pool.rewardAPY;
            pool.totalStaked = pool.totalStaked.add(_amount);
        }
        emit Deposit(msg.sender, _amount, address(pool.lpToken));
    }

    function processPendingReward(uint256 _id) internal {
        PoolInfo storage pool = poolInfo[_id];
        UserInfo storage user = userInfo[msg.sender][_id];
        uint256 lpSupply = pool.totalStaked;

        uint256 rewardAmt = 0;
        if (block.timestamp > user.startBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                user.startBlock,
                block.timestamp,
                _id
            );
            rewardAmt = user
                .amount
                .mul(multiplier)
                .mul(pool.rewardAPY)
                .div(100)
                .div(SECONDS_PER_YEAR);
        }
        if (rewardAmt > 0) {
            pool.lpToken.safeTransfer(address(msg.sender), rewardAmt);
        }
    }

    // Withdraw SYRUP tokens from STAKING.
    function withdraw(uint256 _amount, uint256 _id) public {
        PoolInfo storage pool = poolInfo[_id];
        UserInfo storage user = userInfo[msg.sender][_id];

        require(user.amount >= _amount, "withdraw: not good");
        require(
            user.endBlock <= block.timestamp ||
                pool.bonusEndBlock <= block.timestamp,
            "need to claim after the lock period ends"
        );

        processPendingReward(_id);

        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
            pool.totalStaked = pool.totalStaked.sub(_amount);
        }

        emit Withdraw(msg.sender, _amount, address(pool.lpToken));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _id) public {
        PoolInfo storage pool = poolInfo[_id];
        UserInfo storage user = userInfo[msg.sender][_id];

        require(user.amount > 0, "nothing to withdraw");
        require(
            user.endBlock > block.timestamp &&
                pool.bonusEndBlock > block.timestamp,
            "you can use withdraw function"
        );

        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        pool.totalStaked = pool.totalStaked.sub(user.amount);
        user.amount = 0;
        emit EmergencyWithdraw(msg.sender, user.amount, address(pool.lpToken));
    }
}