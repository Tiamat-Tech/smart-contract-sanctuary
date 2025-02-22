// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import "./TotemVesting.sol";

contract StrategicVesting is TotemVesting {
    uint256 public constant TOTAL_AMOUNT = 1500000 * (10**18);
    uint256 public constant WITHDRAW_INTERVAL = 30 days;
    uint256 public constant RELEASE_PERIODS = 5;
    uint256 public constant LOCK_PERIODS = 0;

    constructor(TotemToken _totemToken)
        TotemVesting(
            _totemToken,
            TOTAL_AMOUNT,
            WITHDRAW_INTERVAL,
            RELEASE_PERIODS,
            LOCK_PERIODS
        )
    {}
}