// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./CropToken.sol";

contract CropFarm is Context {
    mapping(address => StakeDetails) public farmerStakeDetails;

    struct StakeDetails {
        uint256 stakingBalance;
        bool isStaking;
        uint256 startTime;
        uint256 cropBalance;
    }

    address[] private allFarmers;

    string public name = "CropFarm";

    IERC20 public daiToken;
    CropToken public cropToken;

    event Stake(address indexed from, uint256 amount);
    event Unstake(address indexed from, uint256 amount);
    event YieldWithdraw(address indexed to, uint256 amount);

    constructor(IERC20 _daiToken, CropToken _cropToken) {
        daiToken = _daiToken;
        cropToken = _cropToken;
    }

    function stake(uint256 amount) public {
        require(amount > 0, "You cannot stake zero dai");
        require(daiToken.balanceOf(_msgSender()) >= amount, "You do not have enough DAI");

        updateCurrentStakeYield(_msgSender());

        daiToken.transferFrom(_msgSender(), address(this), amount);

        farmerStakeDetails[_msgSender()].stakingBalance += amount;

        if (farmerStakeDetails[_msgSender()].isStaking == false) {
            allFarmers.push(_msgSender());
            farmerStakeDetails[_msgSender()].isStaking = true;
        }

        emit Stake(_msgSender(), amount);
    }

    function unstake(uint256 amount) public {
        require(farmerStakeDetails[_msgSender()].isStaking, "Nothing to unstake");
        require(farmerStakeDetails[_msgSender()].stakingBalance >= amount, "Unstake amount exceeds stake");

        updateCurrentStakeYield(_msgSender());

        farmerStakeDetails[_msgSender()].stakingBalance -= amount;
        if (farmerStakeDetails[_msgSender()].stakingBalance == 0) {
            farmerStakeDetails[_msgSender()].isStaking = false;
        }

        daiToken.transfer(_msgSender(), amount);
        emit Unstake(_msgSender(), amount);
    }

    function withdrawYield() public {
        uint256 toTransfer = farmerStakeDetails[_msgSender()].cropBalance;

        require(toTransfer > 0, "Nothing to withdraw");

        cropToken.mint(_msgSender(), toTransfer);
        emit YieldWithdraw(_msgSender(), toTransfer);
    }

    function updateAllYields() public {
        for (uint256 i = 0; i <= allFarmers.length - 1; i++) {
            updateCurrentStakeYield(allFarmers[i]);
        }
    }

    function calculateYield(address farmer) public view returns (uint256) {
        uint256 yieldTimeSeconds = calculateTimeSpan(farmer);
        uint256 yieldRatePerSecond = calculateYieldRatePerSecond();
        uint256 yieldTotal = yieldTimeSeconds * yieldRatePerSecond;
        return yieldTotal;
    }

    function updateCurrentStakeYield(address farmer) private {
        if (farmerStakeDetails[farmer].isStaking) {
            uint256 yield = calculateYield(farmer);
            farmerStakeDetails[farmer].cropBalance += yield;
        }

        farmerStakeDetails[farmer].startTime = block.timestamp;
    }

    function calculateTimeSpan(address farmer) private view returns (uint256) {
        uint256 endTime = block.timestamp;
        uint256 totalTime = endTime - farmerStakeDetails[farmer].startTime;
        return totalTime;
    }

    function calculateYieldRatePerSecond() private pure returns (uint256) {
        uint256 dailyTokenReward = 20;
        uint256 dailyTokenRewardWithDecimals = dailyTokenReward * 10**18;
        uint256 secondsPerDay = 24 * 60 * 60;
        uint256 tokensPerSecond = dailyTokenRewardWithDecimals / secondsPerDay;
        return tokensPerSecond;
    }
}