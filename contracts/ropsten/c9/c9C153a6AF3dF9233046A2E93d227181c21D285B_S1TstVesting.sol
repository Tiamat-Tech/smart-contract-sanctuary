// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./SafeERC20.sol";
import "./IERC20.sol";

contract TokensVesting {
    using SafeERC20 for IERC20;

    event TokensReleased(uint256 amount);

    // beneficiary of tokens after they are released
    address private _beneficiary;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    uint256 private _start;
    uint256 private _finish;
    uint256 private _duration;
    uint256 private _releasesCount;
    uint256 private _released;

    IERC20 private _token;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * beneficiary, gradually in a linear fashion until start + duration. By then all
     * of the balance will have vested.
     * @param token address of the token which should be vested
     * @param beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param start the time (as Unix time) at which point vesting starts
     * @param duration duration in seconds of each release
     */
    constructor (address token, address beneficiary, uint256 start, uint256 duration, uint256 releasesCount) public {
        require(beneficiary != address(0), "TokensVesting: beneficiary is the zero address!");
        require(token != address(0), "TokensVesting: token is the zero address!");
        require(duration > 0, "TokensVesting: duration is 0!");
        require(releasesCount > 0, "TokensVesting: releases count is 0!");
        require(start + duration > block.timestamp, "TokensVesting: final time is before current time!");

        _token = IERC20(token);
        _beneficiary = beneficiary;
        _duration = duration;
        _releasesCount = releasesCount;
        _start = start;
        _finish = _start + _releasesCount * _duration;
    }


    // -----------------------------------------------------------------------
    // GETTERS
    // -----------------------------------------------------------------------


    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the start time of the token vesting.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @return the finish time of the token vesting.
     */
    function finish() public view returns (uint256) {
        return _finish;
    }

    /**
     * @return the duration of the token vesting.
     */
    function duration() public view returns (uint256) {
        return _duration;
    }

    /**
     * @return the amount of the token released.
     */
    function released() public view returns (uint256) {
        return _released;
    }

    function getAvailableTokens() public view returns (uint256) {
        return _releasableAmount();
    }


    // -----------------------------------------------------------------------
    // SETTERS
    // -----------------------------------------------------------------------


    /**
     * @notice Transfers vested tokens to beneficiary.
     */
    function release() public {
        uint256 unreleased = _releasableAmount();
        require(unreleased > 0, "release: No tokens are due!");

        _released = _released + unreleased;
        _token.safeTransfer(_beneficiary, unreleased);

        emit TokensReleased(unreleased);
    }

    // -----------------------------------------------------------------------
    // INTERNAL
    // -----------------------------------------------------------------------


    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     */
    function _releasableAmount() private view returns (uint256) {
        return _vestedAmount() - _released;
    }

    /**
     * @dev Calculates the amount that has already vested.
     */
    function _vestedAmount() private view returns (uint256) {
        uint256 currentBalance = _token.balanceOf(address(this));
        uint256 totalBalance = currentBalance + _released;

        if (block.timestamp < _start) {
            return 0;
        } else if (block.timestamp >= _finish) {
            return totalBalance;
        } else {
            uint256 timeLeftAfterStart = block.timestamp - _start;
            uint256 availableReleases = timeLeftAfterStart / _duration;
            uint256 tokensPerRelease = totalBalance / _releasesCount;

            return availableReleases * tokensPerRelease;
        }
    }
}

contract S1TstVesting is TokensVesting {
    constructor() TokensVesting(0xFFBfdBac865F1a0911Ab2E0F00b7807F98c38362, 0x6FCCBfC8Dc7EFe5088510588149d774E92A95fd4, 1625349865, 120, 2) {
    }
}