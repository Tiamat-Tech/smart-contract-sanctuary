// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./libraries/PoolDepositable.sol";
import "./libraries/Tierable.sol";
import "./libraries/Suspendable.sol";

/** @title LockedLBToken.
 * @dev PoolDepositable contract implementation with tiers
 */
contract LockedLBToken is PoolDepositable, Tierable, Suspendable {
    constructor(
        IERC20 _depositToken,
        uint256[] memory tiersMinAmount,
        address _pauser
    ) Depositable(_depositToken) Tierable(tiersMinAmount) Suspendable(_pauser) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _deposit(
        address from,
        address to,
        uint256 amount
    ) internal pure override(PoolDepositable, Depositable) returns (uint256) {
        return PoolDepositable._deposit(from, to, amount);
    }

    function _withdraw(address to, uint256 amount)
        internal
        pure
        override(PoolDepositable, Depositable)
        returns (uint256)
    {
        return PoolDepositable._withdraw(to, amount);
    }

    /**
     * @notice Deposit amount token in pool at index `poolIndex` to the sender address balance
     */
    function deposit(uint256 amount, uint256 poolIndex) external whenNotPaused {
        _deposit(_msgSender(), _msgSender(), amount, poolIndex);
    }

    /**
     * @notice Withdraw amount token in pool at index `poolIndex` from the sender address balance
     */
    function withdraw(uint256 amount, uint256 poolIndex)
        external
        whenNotPaused
    {
        _withdraw(_msgSender(), amount, poolIndex);
    }
}