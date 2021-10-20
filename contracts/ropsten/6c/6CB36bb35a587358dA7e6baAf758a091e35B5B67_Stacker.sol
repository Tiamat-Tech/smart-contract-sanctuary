//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./RewardToken.sol";

contract Stacker {

   address rewardToken;
   mapping(address=>uint256) public stacks;
   mapping(address=>uint256) public lastUpdatedTime;
   bool pause = false;
   address public owner;
   uint256 public rewardRate;

   modifier pausable{
       _;
       require(pause==true,"functions are temporarily unavilable");
   }

   modifier onlyOwner{
       _;
       require(msg.sender==owner,"Caller is not the owner");
   }


    constructor(address _rewardToken){
        rewardToken = _rewardToken;
        owner = msg.sender;
    }

    function addStack(uint256 _amount) public {
        bool isDone = RewardToken(rewardToken).transfer(address(this),_amount);
        require(isDone==true,"Transaction Failed");
        stacks[msg.sender] += _amount;
        lastUpdatedTime[msg.sender] = block.timestamp;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner{
        rewardRate = _rewardRate;
    }   

     function totalReward() public view returns (uint) {
        return (((block.timestamp - lastUpdatedTime[msg.sender]) * rewardRate));
    }

    




}