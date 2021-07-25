// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/AutomatedExternalReflector.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract DynaAutoEthDistributor is AutomatedExternalReflector {

    constructor(address tokenAddress) public {
        currentRound = 1;
        totalEthDeposits = address(this).balance;
        currentQueueIndex = 0;
        totalRewardsSent = 0;
        totalCirculatingTokens;
        totalExcludedTokenHoldings;

        maxGas = 400000;
        minGas = 100000;
        maxReflectionsPerRound = 100;
        timeBetweenRounds = 1 minutes;
        nextRoundStart = block.timestamp + 5 minutes;

        allowLowLevelCalls = true;
        reflectionsEnabled = true;
        inDistroMode = true;

        isExcludedFromReflections[tokenAddress] = true;
        tokenContract = ISupportingExternalReflection(tokenAddress);
        totalCirculatingTokens = IERC20(tokenContract).totalSupply();
    }

}