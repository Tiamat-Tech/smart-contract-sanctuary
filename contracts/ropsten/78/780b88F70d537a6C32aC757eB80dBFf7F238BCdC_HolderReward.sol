// SPDX-License-Identifier: No-License
// Copyright (C) 2021 Kamil Dymarczyk

pragma solidity 0.8.4;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./TritonToken.sol";

contract HolderReward is Pausable, ReentrancyGuard, Ownable{
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    // ------------------- constants  -------------------

    uint256 private constant _initialMinimalHoldings       =     20000 * 1e18;  // 20k tokens
    uint256 private constant _initialPoolOverflowThreshold = 999000000 * 1e18;  // n/a
 
    // ------------------- managable attributes -------------------

    TritonToken private _token;
    uint256 private _minimalHoldings;
    uint256 private _poolOverflowThreshold;

    // ------------------- non-managable storage -------------------

    address[] private _distributionHolders;
    uint256[] private _distributionAmounts;

    uint256 private _rewardAmountLTD;

    // ------------------- generated events  -------------------

    event RewardGranted(address indexed account, uint256 tokenAmount);
    event PoolOverflowThresholdUpdatedTo(uint256 poolOverflowThreshold);
    event MinimalHoldingsUpdatedTo(uint256 minimalHoldings);
    
    // ------------------- deployment logic  -------------------

    constructor() {  
        _minimalHoldings = _initialMinimalHoldings;     
        _poolOverflowThreshold = _initialPoolOverflowThreshold;
    }

    // ------------------- getters and setters  -------------------

    // --- token

    function getTokenAddress() public view returns(address) {
        return address(_token);
    }

    function setToken(address tokenAddress) public onlyOwner {
        _token = TritonToken(tokenAddress);
    }

    // --- minimal holdings

    function getMinimalHoldings() public view returns(uint256) {
        return _minimalHoldings;
    }
    function setMinimalHoldings(uint256 minimalHoldings) public onlyOwner {
        _minimalHoldings = minimalHoldings;
        emit MinimalHoldingsUpdatedTo(minimalHoldings);
    }

    // --- pool overflow threshold

    function getPoolOverflowThreshold() public view returns(uint256) {
        return _poolOverflowThreshold;
    }
    function setPoolOverflowThreshold(uint256 poolOverflowThreshold) public onlyOwner {
        _poolOverflowThreshold = poolOverflowThreshold;
        emit PoolOverflowThresholdUpdatedTo(poolOverflowThreshold);
    }

    // --- reward amount ltd

    function getRewardAmountLTD() public view returns(uint256) {
        return _rewardAmountLTD;
    }    

    // ------------------- pause / unpause the contract  -------------------

    function emergencyPause() public onlyOwner whenNotPaused {
        _pause();
    }

    function emergencyUnpause() public onlyOwner whenPaused {
        _unpause();
    }

    // ------------------- rewarding logic  -------------------

    function grantRewards() external onlyOwner nonReentrant whenNotPaused {
        delete _distributionHolders;
        delete _distributionAmounts;

        _token.calculateHolders(_minimalHoldings);
        _distributionHolders = _token.getHolders();
        
        uint256 totalRewardAmount = _token.balanceOf(address(this));
        uint256 distributedRewardAmount = 0;
        uint256 totalHoldingsAmount = getTotalHoldingsAmount();

        for (uint256 i = 0; i < _distributionHolders.length; i++) {
            address holder = _distributionHolders[i];
            uint256 reward = totalRewardAmount * _token.balanceOf(holder) / totalHoldingsAmount;
            reward = min(reward, totalRewardAmount-distributedRewardAmount);
            
            _distributionAmounts.push(reward);
            distributedRewardAmount += reward;
        }
        _token.distributeMyTokensWei(_distributionHolders, _distributionAmounts);
        _rewardAmountLTD += distributedRewardAmount;
    }

    function getTotalHoldingsAmount() internal view returns (uint256) {
        uint256 totalHoldingsAmount = 0;        
        for (uint256 i = 0; i < _distributionHolders.length; i++) {
            totalHoldingsAmount += _token.balanceOf(_distributionHolders[i]);
        }
        return totalHoldingsAmount;
    }

    function min(uint256 value1, uint256 value2) internal pure returns (uint256) {
        if(value1 <= value2) return value1; else return value2;
    }

}