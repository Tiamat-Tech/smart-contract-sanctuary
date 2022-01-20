// SPDX-License-Identifier: MIT
//
//  ________  _______  _________  ___  ___  _______   ________  _______   ___  ___  _____ ______
// |\   __  \|\  ___ \|\___   ___\\  \|\  \|\  ___ \ |\   __  \|\  ___ \ |\  \|\  \|\   _ \  _   \
// \ \  \|\  \ \   __/\|___ \  \_\ \  \\\  \ \   __/|\ \  \|\  \ \   __/|\ \  \\\  \ \  \\\__\ \  \
//  \ \   ____\ \  \_|/__  \ \  \ \ \   __  \ \  \_|/_\ \   _  _\ \  \_|/_\ \  \\\  \ \  \\|__| \  \
//   \ \  \___|\ \  \_|\ \  \ \  \ \ \  \ \  \ \  \_|\ \ \  \\  \\ \  \_|\ \ \  \\\  \ \  \    \ \  \
//    \ \__\    \ \_______\  \ \__\ \ \__\ \__\ \_______\ \__\\ _\\ \_______\ \_______\ \__\    \ \__\
//     \|__|     \|_______|   \|__|  \|__|\|__|\|_______|\|__|\|__|\|_______|\|_______|\|__|     \|__|
//
//
// Pethereum Vesting Wallet Smart Contract
// Welcome to the Pethereum Land!
/// @creator:     Loop Games
/// @author:      archengineer.eth
/// @style:       https://docs.soliditylang.org/en/v0.8.4/style-guide.html

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/PethereumTokenVestingUtils.sol";

/**
 * @title PethereumTokenVestingWallet
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract PethereumTokenVestingWallet is Ownable, Initializable, ReentrancyGuard, PethereumTokenVestingUtils {
    event TokensReleased(address indexed token, uint256 amount);
    event TokenVestingRevoked(address token);

    // Beneficiary of tokens after they are released
    address private _beneficiary;

    // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
    uint256 private _cliff;
    uint256 private _start;
    uint256 private _end;
    uint256 private _duration;
    uint256 private _vestingInterval;

    bool private _revocable;

    mapping(address => uint256) private _released;
    mapping(address => bool) private _revoked;

    // Constructor empty because we are creating vesting wallet via factory clone
    constructor() {}

    /**
     * @dev Initialize vesting wallet
     * @param beneficiary_ The address of the beneficiary.
     * @param start_ Unix date of vesting start in seconds
     * @param cliffDuration_ Unix date of cliff duration in seconds
     * @param duration_ Unix date of total duration in seconds
     * @param vestingIntervalEnumValue_ The enum value of {VestingIntervals} enum. If overflow, yearly vesting works
     * @param revocable_ Is vesting revocable by owner
     */
    function initialize(
        address beneficiary_,
        uint256 start_,
        uint256 cliffDuration_,
        uint256 duration_,
        uint8 vestingIntervalEnumValue_,
        bool revocable_
    )
    external
    initializer
    {
        require(beneficiary_ != address(0),
            "PethereumTokenVestingWallet: beneficiary is the zero address");
        require(cliffDuration_ <= duration_,
            "PethereumTokenVestingWallet: cliffDuration is longer than duration");
        require(duration_ > 0,
            "PethereumTokenVestingWallet: duration is 0");
        require(start_ + duration_ > getCurrentTime(),
            "PethereumTokenVestingWallet: final time before current time");
        require(vestingIntervalEnumValue_ > 0,
            "PethereumTokenVestingWallet: vesting interval enum value cannot be negative");

        _beneficiary = beneficiary_;

        _duration = duration_;
        _cliff = start_ + cliffDuration_;
        _start = start_;
        _end = start_ + duration_;

        _vestingInterval = convertVestingIntervalEnumValueToTimestampInSeconds(
            vestingIntervalEnumValue_
        );

        _revocable = revocable_;
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }

    /**
     * @return the cliff time of the token vesting.
     */
    function cliff() public view virtual returns (uint256) {
        return _cliff;
    }

    /**
     * @return the start time of the token vesting.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @return the end time of the token vesting.
     */
    function end() public view virtual returns (uint256) {
        return _end;
    }

    /**
     * @return the duration of the token vesting.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @return the vesting interval in seconds.
     */
    function vestingInterval() public view virtual returns (uint256) {
        return _vestingInterval;
    }

    /**
     * @return true if the vesting is revocable.
     */
    function revocable() public view virtual returns (bool) {
        return _revocable;
    }

    /**
     * @return the amount of the token released.
     */
    function released(address token) public view virtual returns (uint256) {
        return _released[token];
    }

    /**
     * @return true if the token is revoked.
     */
    function revoked(address token) public view virtual returns (bool) {
        return _revoked[token];
    }

    function getDaysVested(uint256 timestamp) public view virtual returns (uint256) {
        return timestamp - start();
    }

    function getEffectiveDaysVested(uint256 timestamp) public view virtual returns (uint256) {
        uint256 daysVested = timestamp - start();
        return (daysVested / vestingInterval()) * vestingInterval();
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokensReleased} event.
     */
    function release(address token) public virtual nonReentrant {
        uint256 releasable = vestedAmount(token, getCurrentTime()) - released(token);
        require(releasable > 0, "PethereumTokenVestingWallet: no tokens are due");

        _released[token] += releasable;

        emit TokensReleased(token, releasable);
        SafeERC20.safeTransfer(IERC20(token), beneficiary(), releasable);
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(
        address token,
        uint256 timestamp
    )
    public
    view
    virtual
    returns (uint256)
    {
        return _vestingSchedule(token, timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(
        address token,
        uint256 timestamp
    )
    internal
    view virtual
    returns (uint256)
    {
        // Calculate total allocation for token
        uint256 totalAllocation = IERC20(token).balanceOf(address(this)) + released(token);

        if (timestamp < cliff()) {
            return 0;
        } else if (timestamp < start()) {
            return 0;
        } else if (timestamp > end() || revoked(token)) {
            return totalAllocation;
        } else {
            // Compute the exact number of days vested
            uint256 daysVested = timestamp - start();
            // Adjust result rounding down to take into consideration the interval
            uint256 effectiveDaysVested = (daysVested / vestingInterval()) * vestingInterval();

            // Calculate unlocked vested amount with interval consideration
            uint256 vested = (totalAllocation * effectiveDaysVested) / _duration;

            return vested;
        }
    }
}