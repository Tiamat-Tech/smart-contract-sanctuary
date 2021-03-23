// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract TestBase is ReentrancyGuard, Ownable {

    uint256 private _unlockTime;

    constructor(uint256 unlockTime_) {
        _unlockTime = unlockTime_;
    }

    function unlockTime() public view returns (uint256) {
        return _unlockTime;
    }

}