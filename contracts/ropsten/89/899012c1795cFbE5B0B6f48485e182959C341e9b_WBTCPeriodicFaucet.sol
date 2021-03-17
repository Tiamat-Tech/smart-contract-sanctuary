// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "../token/MockBTC.sol";

contract PeriodicFaucet is Context {
    using SafeMath for uint256;

    MockBTC public token;
    uint256 unitAmount;

    uint256 startTime;
    uint256 period = 4 hours;

    mapping(address => uint256) private nextClaim;

    constructor(
        MockBTC _token,
        uint256 _unitAmount,
        uint256 _startTime
    ) public {
        require(address(_token) != address(0), "zero address");
        require(address(_token) != address(0), "zero address");

        token = _token;
        unitAmount = _unitAmount;
        startTime = _startTime;
    }

    function claim() public {
        require(currentTime() >= startTime, "not started");

        uint256 _currPeriod = currentPeriod();
        require(nextClaim[_msgSender()] <= _currPeriod, "too frequent");

        token.mint(_msgSender(), unitAmount);
        nextClaim[_msgSender()] = _currPeriod.add(1);
    }

    function currentTime() private view returns (uint256) {
        return block.timestamp;
    }

    function currentPeriod() private view returns (uint256) {
        return block.timestamp.div(period);
    }
}