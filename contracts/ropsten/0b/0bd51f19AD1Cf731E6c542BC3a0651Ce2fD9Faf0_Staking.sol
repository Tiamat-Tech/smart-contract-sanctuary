// SPDX-License-Identifier: UNLICENSED

// Code by zipzinger and cmtzco
// DEFIBOYS
// defiboys.com

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Staking is Ownable {
    mapping(address => bool) staked;
    mapping(address => uint256) stakedAmount;
    mapping(address => uint256) lastTxnBlock;
    mapping(address => uint256) spentAmount;
    mapping(address => uint256) summarizedReward;

    uint256 public rewardRate = 1;

    function setRewardRate(uint256 _newRate) public onlyOwner {
        require(_newRate > 0, "rewardRate must be greater than zero");
        rewardRate = _newRate;
    }

    function testStake(uint256 _num) public onlyOwner {
        staked[msg.sender] = true;
        stakedAmount[msg.sender] = _num;
        lastTxnBlock[msg.sender] = block.number;
        spentAmount[msg.sender] = 0;
        summarizedReward[msg.sender] = 0;
    }

    function testAddStake(uint256 _num) public onlyOwner {
        require(staked[msg.sender], "Run testStake() first");
        summarizedReward[msg.sender] = SafeMath.add(summarizedReward[msg.sender], rewardBalance(payable(msg.sender)));
        spentAmount[msg.sender] = 0;
        stakedAmount[msg.sender] = SafeMath.add(stakedAmount[msg.sender], _num);
        lastTxnBlock[msg.sender] = block.number;
    }

    function rewardBalance(address payable _addr) public view returns (uint256) {
        uint256 blockdiff = SafeMath.sub(block.number, lastTxnBlock[_addr]);
        uint256 inner = SafeMath.mul(rewardRate, SafeMath.mul(stakedAmount[_addr], blockdiff));
        uint256 result = SafeMath.add(summarizedReward[_addr], SafeMath.sub(inner, spentAmount[_addr]));
        return result;
    }

    function stake() payable public {
        if (!staked[msg.sender]) {
            staked[msg.sender] = true;
            stakedAmount[msg.sender] = 0; // FIX HERE
            lastTxnBlock[msg.sender] = block.number;
            spentAmount[msg.sender] = 0;
            summarizedReward[msg.sender] = 0;
        } else {
            summarizedReward[msg.sender] += rewardBalance(payable(msg.sender));
            spentAmount[msg.sender] = 0;
            stakedAmount[msg.sender] += 0; // FIX HERE
            lastTxnBlock[msg.sender] = block.number;
        }
    }
}