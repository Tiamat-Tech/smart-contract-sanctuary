//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OracleDaily is Ownable {
    mapping(string => uint256) public dailyBlockCount;
    mapping(string => uint256) public dailyGasFees;

    constructor() {
        console.log("Deploying a OracleDaily");
    }

    function addDaily(
        string memory day,
        uint256 _dailyBlockCount,
        uint256 _dailyGasFees
    ) public onlyOwner {
        dailyBlockCount[day] = _dailyBlockCount;
        dailyGasFees[day] = _dailyGasFees;
    }
}