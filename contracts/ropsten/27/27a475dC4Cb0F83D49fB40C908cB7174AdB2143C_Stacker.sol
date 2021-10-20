//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./RewardToken.sol";

contract Stacker {

    RewardToken rewardToken;
   mapping(address=>uint256) stacks;
   bool pause = false;
   address owner;

   modifier pausable{
       _;
       require(pause==true,"functions are temporarily unavilable");
   }

   modifier onlyOwner{
       _;
       require(msg.sender==owner,"Caller is not the owner");
   }


    constructor(){
        rewardToken = new RewardToken("RewardToken","RT");
        owner = msg.sender;
    }

    function addStack(uint256 _amount) public {
        rewardToken.transfer(msg.sender,address(this),_amount);
    }   
}