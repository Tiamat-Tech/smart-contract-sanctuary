//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IStakingExpPool.sol";
import "../interfaces/IMoonKnight.sol";
import "../utils/AcceptedToken.sol";

contract StakingExpPool is IStakingExpPool, AcceptedToken {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.UintSet;

    uint private constant BASE_EXP = 1000;

    IMoonKnight public knightContract;

    // Mapping from Knight to its current EXP.
    mapping(uint => uint) private _knightExp;

    // Mapping from an address to Knight with staking balance.
    mapping(address => mapping(uint => uint)) private _stakingBalances;

    // Mapping from an address to staking Knights.
    mapping(address => EnumerableSet.UintSet) private _addrToStakingKnights;

    // Mapping from address to Knight with latest updated timestamp.
    mapping(address => mapping(uint => uint)) private _knightWithTimestamp;

    constructor(IERC20 tokenAddr, IMoonKnight knightAddr) AcceptedToken(tokenAddr) {
        knightContract = knightAddr;
    }

    function setMoonKnightContract(IMoonKnight knightAddr) external onlyOwner {
        require(address(knightAddr) != address(0));
        knightContract = knightAddr;
    }

    function stake(
        uint knightId,
        uint amount
    ) external override collectTokenAsFee(amount, address(this)) {
        address account = msg.sender;

        _harvestExp(knightId, account);

        uint newBalance = _stakingBalances[account][knightId] + amount;
        _stakingBalances[account][knightId] = newBalance;
        _addrToStakingKnights[account].add(knightId);

        emit Staked(knightId, account, newBalance, amount);
    }

    function unstake(uint knightId, uint amount) external override {
        address account = msg.sender;
        uint stakingBalance = _stakingBalances[account][knightId];

        require(stakingBalance >= amount, "StakingExpPool: insufficient token balance");

        _harvestExp(knightId, account);

        uint newBalance = stakingBalance - amount;
        _stakingBalances[account][knightId] = newBalance;

        if (newBalance == 0) _addrToStakingKnights[account].remove(knightId);

        acceptedToken.safeTransfer(account, amount);

        emit Unstaked(knightId, account, newBalance, amount);
    }

    function convertExpToLevels(uint knightId, uint levelUpAmount) external override {
        _harvestExp(knightId, msg.sender);

        uint currentLevel = knightContract.getKnightLevel(knightId);
        uint currentExp = _knightExp[knightId];
        uint requiredExp = (levelUpAmount * (2 * currentLevel + levelUpAmount - 1) / 2) * BASE_EXP * 1e18;

        require(currentExp >= requiredExp, "StakingExpPool: not enough exp");

        _knightExp[knightId] -= requiredExp;
        knightContract.levelUp(knightId, levelUpAmount);
    }

    function exit() external override {
        address account = msg.sender;
        EnumerableSet.UintSet storage stakingKnights = _addrToStakingKnights[account];
        uint count = stakingKnights.length();

        require(count > 0, "StakingExpPool: nothing to withdraw");

        uint[] memory knightIds = new uint[](count);
        for (uint i = 0; i < count; i++) {
            knightIds[i] = stakingKnights.at(i);
        }

        uint totalBalance;
        for (uint i = 0; i < count; i++) {
            uint knightId = knightIds[i];

            _harvestExp(knightId, account);
            totalBalance += _stakingBalances[account][knightId];
            _stakingBalances[account][knightId] = 0;
            stakingKnights.remove(knightId);
        }

        acceptedToken.safeTransfer(account, totalBalance);

        emit Exited(account, totalBalance);
    }

    function getExpEarned(uint knightId, address account) public view override returns (uint) {
        uint lastUpdatedTime = _knightWithTimestamp[account][knightId];
        uint stakedTimeInSeconds = lastUpdatedTime == 0 ? 0 : block.timestamp - lastUpdatedTime;

        return _stakingBalances[account][knightId] * stakedTimeInSeconds / 1e5;
    }

    function balanceOf(uint knightId, address account) external view override returns (uint) {
        return _stakingBalances[account][knightId];
    }

    function _harvestExp(uint knightId, address account) private {
        _knightExp[knightId] += getExpEarned(knightId, account);
        _knightWithTimestamp[account][knightId] = block.timestamp;
    }
}