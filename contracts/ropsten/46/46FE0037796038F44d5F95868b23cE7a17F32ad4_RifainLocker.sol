// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract RifainLocker is TimelockController {

    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) 
    TimelockController(minDelay,proposers,executors)
   {} 
}