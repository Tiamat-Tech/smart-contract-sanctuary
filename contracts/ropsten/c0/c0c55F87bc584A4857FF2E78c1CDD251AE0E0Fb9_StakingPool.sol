//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IStakingPool.sol";
import "../interfaces/IRewardDistributor.sol";
import "../interfaces/IMoonKnight.sol";
import "../utils/PermissionGroup.sol";

contract StakingPool is IStakingPool, PermissionGroup {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    uint public constant BASE_APY = 5;
    uint private constant ONE_YEAR_IN_SECONDS = 31536000;

    IERC20 public immutable acceptedToken;
    IRewardDistributor public immutable rewardDistributorContract;
    IMoonKnight public knightContract;
    uint public baseExp = 1000;
    uint public maxApy = 30;
    uint public endTime;
    mapping(uint => uint) public knightExp;
    mapping(address => mapping(uint => StakingData)) public stakingData;

    // All staking Knights of an address
    mapping(address => EnumerableSet.UintSet) private _stakingKnights;

    constructor(
        IERC20 tokenAddr,
        IMoonKnight knightAddr,
        IRewardDistributor distributorAddr
    ) {
        acceptedToken = tokenAddr;
        knightContract = knightAddr;
        rewardDistributorContract = distributorAddr;
    }

    function setMoonKnightContract(IMoonKnight knightAddr) external onlyOwner {
        require(address(knightAddr) != address(0));
        knightContract = knightAddr;
    }

    function setMaxApy(uint value) external onlyOwner {
        require(value > BASE_APY);
        maxApy = value;
    }

    function setBaseExp(uint value) external onlyOwner {
        require(value > 0);
        baseExp = value;
    }

    function endReward() external onlyOwner {
        endTime = block.timestamp;
    }

    function stake(uint knightId, uint amount, uint lockedMonths) external override {
        address account = msg.sender;

        StakingData storage stakingKnight = stakingData[account][knightId];

        if (block.timestamp < stakingKnight.lockedTime) {
            require(lockedMonths >= stakingKnight.lockedMonths, "StakingPool: lockMonths must be equal or higher");
        }

        _harvest(knightId, account);

        uint apy = lockedMonths * BASE_APY;
        stakingKnight.APY = apy == 0 ? BASE_APY : apy > maxApy ? maxApy : apy;
        stakingKnight.balance += amount;
        stakingKnight.lockedTime = block.timestamp + lockedMonths * 30 days;
        stakingKnight.lockedMonths = lockedMonths;

        _stakingKnights[account].add(knightId);

        acceptedToken.safeTransferFrom(account, address(this), amount);

        emit Staked(knightId, account, amount, lockedMonths);
    }

    function unstake(uint knightId, uint amount) external override {
        address account = msg.sender;
        StakingData storage stakingKnight = stakingData[account][knightId];

        require(block.timestamp >= stakingKnight.lockedTime, "StakingPool: still locked");
        require(stakingKnight.balance >= amount, "StakingPool: insufficient balance");

        _harvest(knightId, account);

        uint newBalance = stakingKnight.balance - amount;
        stakingKnight.balance = newBalance;

        if (newBalance == 0) {
            _stakingKnights[account].remove(knightId);
            stakingKnight.APY = 0;
            stakingKnight.lockedTime = 0;
            stakingKnight.lockedMonths = 0;
        }

        acceptedToken.safeTransfer(account, amount);

        emit Unstaked(knightId, account, amount);
    }

    function claim(uint knightId) external override {
        address account = msg.sender;
        StakingData storage stakingKnight = stakingData[account][knightId];

        require(stakingKnight.balance > 0);

        _harvest(knightId, account);

        uint reward = stakingKnight.reward;
        stakingKnight.reward = 0;
        rewardDistributorContract.distributeReward(account, reward);

        emit Claimed(knightId, account, reward);
    }

    function convertExpToLevels(uint knightId, uint levelUpAmount) external override {
        _harvest(knightId, msg.sender);

        uint currentLevel = knightContract.getKnightLevel(knightId);
        uint currentExp = knightExp[knightId];
        uint requiredExp = (levelUpAmount * (2 * currentLevel + levelUpAmount - 1) / 2) * baseExp * 1e18;

        require(currentExp >= requiredExp, "StakingPool: not enough exp");

        knightExp[knightId] -= requiredExp;
        knightContract.levelUp(knightId, levelUpAmount);
    }

    function earned(uint knightId, address account) public view override returns (uint expEarned, uint tokenEarned) {
        StakingData memory stakingKnight = stakingData[account][knightId];
        uint lastUpdatedTime = stakingKnight.lastUpdatedTime;
        uint currentTime = endTime != 0 ? endTime : block.timestamp;
        uint stakedTime = lastUpdatedTime > currentTime ? 0 : currentTime - lastUpdatedTime;
        uint stakedTimeInSeconds = lastUpdatedTime == 0 ? 0 : stakedTime;
        uint stakingDuration = stakingKnight.balance * stakedTimeInSeconds;

        expEarned = stakingDuration / 1e5;
        tokenEarned = stakingDuration / ONE_YEAR_IN_SECONDS * stakingKnight.APY / 100;
    }

    function balanceOf(uint knightId, address account) external view override returns (uint) {
        return stakingData[account][knightId].balance;
    }

    function _harvest(uint knightId, address account) private {
        (uint expEarned, uint tokenEarned) = earned(knightId, account);

        knightExp[knightId] += expEarned;

        StakingData storage stakingKnight = stakingData[account][knightId];
        stakingKnight.lastUpdatedTime = block.timestamp;
        stakingKnight.reward += tokenEarned;
    }
}