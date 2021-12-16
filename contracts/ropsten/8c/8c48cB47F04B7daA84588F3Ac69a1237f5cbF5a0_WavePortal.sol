// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract WavePortal {
    uint256 private totalWaves;

    mapping(address => uint256) peoplesWaves;

    constructor() {
        console.log("Yo yo, I am a contract and I am smart");
        totalWaves = 0;
    }

    function wave() public {
        totalWaves += 1;
        peoplesWaves[msg.sender]++;
        console.log("%s has waved!", msg.sender);
        console.log(
            "%s has waved %d times.",
            msg.sender,
            peoplesWaves[msg.sender]
        );
    }

    function getTotalWaves() public view returns (uint256) {
        console.log("We have %d total waves!", totalWaves);
        return totalWaves;
    }
}