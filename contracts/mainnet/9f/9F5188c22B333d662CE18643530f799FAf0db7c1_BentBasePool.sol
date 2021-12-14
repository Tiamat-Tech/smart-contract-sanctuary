// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "../libraries/Errors.sol";
import "../interfaces/IOwnable.sol";
import "../interfaces/IBentPool.sol";
import "../interfaces/IBentPoolManager.sol";
import "../interfaces/convex/IConvexBooster.sol";
import "../interfaces/convex/IBaseRewardPool.sol";
import "../interfaces/convex/IConvexToken.sol";
import "../interfaces/convex/IVirtualBalanceRewardPool.sol";
import "./BentBasePoolUpgradeable.sol";

contract BentBasePool is BentBasePoolUpgradeable {
    constructor(
        address _poolManager,
        string memory _name,
        uint256 _cvxPoolId,
        address[] memory _extraRewardTokens,
        uint256 _windowLength // around 7 days
    ) {
        initialize(
            _poolManager,
            _name,
            _cvxPoolId,
            _extraRewardTokens,
            _windowLength
        );
    }
}