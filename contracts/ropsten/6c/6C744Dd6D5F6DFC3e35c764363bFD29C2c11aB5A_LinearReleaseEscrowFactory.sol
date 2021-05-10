// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./LinearReleaseEscrow.sol";

/**
 * @dev A factory to deploy instances of LinearReleaseEscrow with with given parameters
 *
 */
contract LinearReleaseEscrowFactory {
    /* ============ Events ============ */

    event LinearReleaseEscrowCreated(
        address indexed timedEscrow_,
        address token_,
        uint256 startAccrualTime_,
        uint256 releaseTime_,
        uint256 rescueTime_,
        address rescuer_,
        address manager_
    );

    /* ============ Functions ============ */
    function create(
        IERC20 token_,
        uint256 startAccrualTime_,
        uint256 releaseTime_,
        uint256 rescueTime_,
        address rescuer_,
        address manager_
    ) external returns (address) {
        LinearReleaseEscrow linearReleaseEscrow =
            new LinearReleaseEscrow(
                token_,
                startAccrualTime_,
                releaseTime_,
                rescueTime_,
                rescuer_,
                manager_
            );

        emit LinearReleaseEscrowCreated(
            address(linearReleaseEscrow),
            address(token_),
            startAccrualTime_,
            releaseTime_,
            rescueTime_,
            rescuer_,
            manager_
        );

        return address(linearReleaseEscrow);
    }
}