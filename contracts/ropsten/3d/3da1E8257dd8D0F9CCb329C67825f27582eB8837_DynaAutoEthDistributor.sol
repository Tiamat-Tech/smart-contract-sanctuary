// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./utils/AutomatedExternalReflector.sol";

contract DynaAutoEthDistributor is AutomatedExternalReflector {

    constructor(address tokenAddress) public {
        currentRound = 1;
        totalEthDeposits = address(this).balance;
        currentQueueIndex = 0;
        totalRewardsSent = 0;
        totalCirculatingTokens;
        totalExcludedTokenHoldings;

        maxGas = 400000;
        minGas = 200000;
        maxReflectionsPerRound = 100;
        timeBetweenRounds = 1 hours;
        nextRoundStart = block.timestamp + 5 minutes;

        allowLowLevelCalls = true;
        reflectionsEnabled = true;
        inDistroMode = false;

        tokenContract = ISupportingExternalReflection(tokenAddress);
    }

}