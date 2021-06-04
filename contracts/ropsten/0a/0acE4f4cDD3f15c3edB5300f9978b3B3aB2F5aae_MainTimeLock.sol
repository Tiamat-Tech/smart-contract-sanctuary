// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/utils/TokenTimelock.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract MainTimeLock is TokenTimelock {
    constructor(
        IERC20 token,
        address addr,
        uint256 releaseTime
    ) TokenTimelock(token, addr, releaseTime) {}
}