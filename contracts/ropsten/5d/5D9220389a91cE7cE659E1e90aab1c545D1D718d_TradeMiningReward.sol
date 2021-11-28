//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/Ownable.sol";
//npm install @openzeppelin/contracts
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract TradeMiningReward is Ownable {
    using SafeMath for uint256;

    uint256 private rewardPerc;
    uint256 public stakeTarget;
    uint256 public txGasUnit;
    uint256 public gasFee;
    uint256 public timePeriod = 4 seconds; // set to 2 weeks, 4 sec for debugging

    event AllocateAmount(uint256 amount);
    event ClaimAmount(uint256 amount);
    mapping(address => uint256) public lockedRewards; // locked allocated reward
    mapping(address => uint256) public unlockedRewards; // collectable reward
    mapping(address => uint256) public nextClaimDate; // track whether user claimed when unlocked

    constructor() {
        rewardPerc = 40; //set to 40%, 1 = 1%
        txGasUnit = 46666666666666; //(estimated gas used) avg transaction fee about 0.007 ether = 0.007e18 wei, assuming avg gas price is 150 wei then it is 46,666,666,666,667 gas used
        stakeTarget = 2000;
    }

    //initial plan estimate all wei to pendle value and store it as pendle value, but it will be decimal

    /* ----------------------------------imitate function (this function should in other contract)------------------------------------------*/
    function swap(uint256 stakePerc, uint256 gasPrice) public {
        //imitate swap function
        //do magic swap
        checkUnlockable();
        allocateRewards(stakePerc, gasPrice); // allocate reward
    }

    /* ----------------------------------Main function------------------------------------------*/
    function claimRewardsV2() public {
        // imitate function claimRewards
        checkUnlockable();
        uint256 amount = getUnlockedBalance();
        require(amount > 0, "Nothing to claim");
        clearUnlockReward();
        emit ClaimAmount(amount);
    }

    function checkUnlockable() internal {
        //user will call this function to claim all their unlockRewards
        if (getLockedBalance() > 0) {
            if (getClaimDate() <= block.timestamp) {
                // set new nextClaimDate & move lock to unlock
                lockToUnlock();
                setClaimDate();
            }
        }
    }

    /* ----------------------------------External function------------------------------------------*/
    // should be external since swap from other contract will call this function
    function allocateRewards(uint256 stakePerc, uint256 gasPrice) internal {
        // gas fee * (basic + stake), allocate locked rewards after swap function
        uint256 amount;
        uint256 totalPerc = rewardPerc;
        updateGasFee(gasPrice);
        if (getClaimDate() == 0) {
            // check is it new user then set time for new user
            setClaimDate();
        }
        if (stakePerc >= stakeTarget) {
            // if stake more than 2000 token
            totalPerc = rewardPerc.add(10); // basic + stake
        }
        require(totalPerc <= 100, "No more than 100%");
        amount = gasFee.mul(totalPerc).div(100); // (gasPrice * txGasUnit) * (basic + stake)
        lockedRewards[msg.sender] = lockedRewards[msg.sender].add(amount); // value stored in wei
        emit AllocateAmount(amount);
    }

    /* ----------------------------------Should be internal function, set to public for testing purpose------------------------------------------*/

    // should be internal only called by claim
    function lockToUnlock() internal {
        require(getClaimDate() < block.timestamp, "Still not unlockable");
        require(lockedRewards[msg.sender] > 0, "Nothing to unlock");
        unlockedRewards[msg.sender] = unlockedRewards[msg.sender].add(
            lockedRewards[msg.sender]
        );
        lockedRewards[msg.sender] = 0; // reset to 0 value
    }

    // should be internal only called by claimRewards
    function clearUnlockReward() internal {
        //reward claimed, set unlockedRewards to 0
        unlockedRewards[msg.sender] = 0;
        require(unlockedRewards[msg.sender] == 0, "Reward not cleaned up");
    }

    // should be internal only called when allocateRewards
    function updateGasFee(uint256 gasPrice) internal {
        require(gasPrice > 0, "gas Price > 0");
        gasFee = txGasUnit.mul(gasPrice);
    }

    function setClaimDate() internal {
        // set next claimable date after claimed
        nextClaimDate[msg.sender] = block.timestamp.add(timePeriod);
    }

    /* ----------------------------------Only owner function------------------------------------------*/
    function setRewardPerc(uint256 newPerc) public onlyOwner {
        //only owner can set %
        require(newPerc <= 100, "No more than 100%");
        rewardPerc = newPerc;
    }

    function setTxGasUnit(uint256 newGas) public onlyOwner {
        txGasUnit = newGas;
    }

    function setStakeTarget(uint256 newLimit) public onlyOwner {
        stakeTarget = newLimit;
    }

    /* ----------------------------------All view function------------------------------------------*/

    function getRewardPerc() public view onlyOwner returns (uint256) {
        return rewardPerc;
    }

    function getLockedBalance() public view returns (uint256) {
        return lockedRewards[msg.sender];
    }

    function getUnlockedBalance() public view returns (uint256) {
        return unlockedRewards[msg.sender];
    }

    function getClaimDate() public view returns (uint256) {
        return nextClaimDate[msg.sender];
    }

    receive() external payable {
        // accept ETH
    }
}