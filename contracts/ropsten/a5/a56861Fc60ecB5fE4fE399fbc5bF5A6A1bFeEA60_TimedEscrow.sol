// SPDX-License-Identifier: MIT

pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time. The rescuer can recover back the tokens
 * after the recovery time
 *
 */
contract TimedEscrow {
    using SafeERC20 for IERC20;

    // ERC20 basic token contract being held
    IERC20 private _token;

    // beneficiary of tokens after they are released
    address private _beneficiary;

    // timestamp when token release is enabled
    uint256 private _releaseTime;

    // beneficiary of tokens after the recovery time
    address private _rescuer;

    // timestamp when token can be recovered
    uint256 private _recoveryTime;

    constructor(
        IERC20 token_,
        address beneficiary_,
        uint256 releaseTime_,
        address rescuer_,
        uint256 recoveryTime_
    ) {
        // solhint-disable-next-line not-rely-on-time
        require(
            releaseTime_ > block.timestamp,
            "TimedEscrow: release time is not after current time"
        );
        // solhint-disable-next-line not-rely-on-time
        require(
            recoveryTime_ > releaseTime_,
            "TimedEscrow: recovery time is not after release time"
        );
        _token = token_;
        _beneficiary = beneficiary_;
        _releaseTime = releaseTime_;
        _rescuer = rescuer_;
        _recoveryTime = recoveryTime_;
    }

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20) {
        return _token;
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }

    /**
     * @return the time when the tokens are released.
     */
    function releaseTime() public view virtual returns (uint256) {
        return _releaseTime;
    }

    /**
     * @return the current token balance.
     */
    function balance() public view virtual returns (uint256) {
        return token().balanceOf(address(this));
    }

    /**
     * @return the rescuer of the tokens.
     */
    function rescuer() public view virtual returns (address) {
        return _rescuer;
    }

    /**
     * @return the time when the tokens can be recovered.
     */
    function recoveryTime() public view virtual returns (uint256) {
        return _recoveryTime;
    }

    /**
     * @notice Transfers tokens held by the contract to the beneficiary.
     */
    function release() public virtual {
        // solhint-disable-next-line not-rely-on-time
        require(
            block.timestamp >= releaseTime(),
            "TimedEscrow: current time is before release time"
        );

        require(
            address(msg.sender) == _beneficiary,
            "TimedEscrow: only the beneficiary can release the funds"
        );

        uint256 amount = token().balanceOf(address(this));
        require(amount > 0, "TimedEscrow: no tokens to release");

        token().safeTransfer(beneficiary(), amount);
    }

    /**
     * @notice Transfers tokens held by the contract to the rescuer.
     */
    function rescue() public virtual {
        // solhint-disable-next-line not-rely-on-time
        require(
            block.timestamp >= recoveryTime(),
            "TimedEscrow: current time is before recovery time"
        );

        uint256 amount = token().balanceOf(address(this));
        require(amount > 0, "TimedEscrow: no tokens to release");

        token().safeTransfer(rescuer(), amount);
    }
}