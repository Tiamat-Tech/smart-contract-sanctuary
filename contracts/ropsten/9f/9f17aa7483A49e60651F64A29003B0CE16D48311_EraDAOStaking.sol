// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EraDAOStaking is ERC20("sERA", "sERA"), Ownable {
    using SafeERC20 for IERC20;
    using SafeCast for int256;
    using SafeCast for uint256;

    struct Config {
        // Timestamp in seconds is small enough to fit into uint64
        uint64 periodFinish;
        uint64 periodStart;

        // Staking incentive rewards to distribute in a steady rate
        uint128 totalReward;
    }

    IERC20 public era;
    Config public config;

    /*
     * Construct an EraDAOStaking contract.
     *
     * @param _era the contract address of ERA token
     * @param _periodStart the initial start time of rewards period
     * @param _rewardsDuration the duration of rewards in seconds
     */
    constructor(IERC20 _era, uint64 _periodStart, uint64 _rewardsDuration) {
        require(address(_era) != address(0), "EraDAOStaking: _era cannot be the zero address");
        era = _era;
        setPeriod(_periodStart, _rewardsDuration);
    }

    /*
     * Add ERA tokens to the reward pool.
     *
     * @param _eraAmount the amount of ERA tokens to add to the reward pool
     */
    function addRewardERA(uint256 _eraAmount) external {
        Config memory cfg = config;
        require(block.timestamp < cfg.periodFinish, "EraDAOStaking: Adding rewards is forbidden");

        era.safeTransferFrom(msg.sender, address(this), _eraAmount);
        cfg.totalReward += _eraAmount.toUint128();
        config = cfg;
    }

    /*
     * Set the reward peroid. If only possible to set the reward period after last rewards have been
     * expired.
     *
     * @param _periodStart timestamp of reward starting time
     * @param _rewardsDuration the duration of rewards in seconds
     */
    function setPeriod(uint64 _periodStart, uint64 _rewardsDuration) public onlyOwner {
        require(_periodStart >= block.timestamp, "EraDAOStaking: _periodStart shouldn't be in the past");
        require(_rewardsDuration > 0, "EraDAOStaking: Invalid rewards duration");

        Config memory cfg = config;
        require(cfg.periodFinish < block.timestamp, "EraDAOStaking: The last reward period should be finished before setting a new one");

        uint64 _periodFinish = _periodStart + _rewardsDuration;
        config.periodStart = _periodStart;
        config.periodFinish = _periodFinish;
        config.totalReward = 0;
    }

    /*
     * Returns the staked era + release rewards
     *
     * @returns amount of available era
     */
    function getERAPool() public view returns(uint256) {
        return era.balanceOf(address(this)) - frozenRewards();
    }

    /*
     * Returns the frozen rewards
     *
     * @returns amount of frozen rewards
     */
    function frozenRewards() public view returns(uint256) {
        Config memory cfg = config;

        uint256 time = block.timestamp;
        uint256 remainingTime;
        uint256 duration = uint256(cfg.periodFinish) - uint256(cfg.periodStart);

        if (time <= cfg.periodStart) {
            remainingTime = duration;
        } else if (time >= cfg.periodFinish) {
            remainingTime = 0;
        } else {
            remainingTime = cfg.periodFinish - time;
        }

        return remainingTime * uint256(cfg.totalReward) / duration;
    }

    /*
     * Staking specific amount of ERA token and get corresponding amount of sERA
     * as the user's share in the pool
     *
     * @param _eraAmount
     */
    function enter(uint256 _eraAmount) external {
        require(_eraAmount > 0, "EraDAOStaking: Should at least stake something");

        uint256 totalERA = getERAPool();
        uint256 totalShares = totalSupply();

        era.safeTransferFrom(msg.sender, address(this), _eraAmount);

        if (totalShares == 0 || totalERA == 0) {
            _mint(msg.sender, _eraAmount);
        } else {
            uint256 _share = _eraAmount * totalShares / totalERA;
            _mint(msg.sender, _share);
        }
    }

    /*
     * Redeem specific amount of sERA to ERA tokens according to the user's share in the pool.
     * sERA will be burnt.
     *
     * @param _share
     */
    function leave(uint256 _share) external {
        require(_share > 0, "EraDAOStaking: Should at least unstake something");

        uint256 totalERA = getERAPool();
        uint256 totalShares = totalSupply();

        _burn(msg.sender, _share);

        uint256 _eraAmount = _share * totalERA / totalShares;
        era.safeTransfer(msg.sender, _eraAmount);
    }
}