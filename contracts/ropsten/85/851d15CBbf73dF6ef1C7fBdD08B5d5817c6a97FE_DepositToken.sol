// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import '../../dependencies/openzeppelin/contracts/IERC20.sol';
import '../../dependencies/openzeppelin/contracts/SafeERC20.sol';
import '../../tools/math/WadRayMath.sol';
import '../../tools/upgradeability/VersionedInitializable.sol';
import './interfaces/PoolTokenConfig.sol';
import './base/DepositTokenBase.sol';

/// @dev Deposit token, an interest bearing token for the Augmented Finance protocol
contract DepositToken is DepositTokenBase, VersionedInitializable {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  uint256 private constant TOKEN_REVISION = 0x1;

  function getRevision() internal pure virtual override returns (uint256) {
    return TOKEN_REVISION;
  }

  function initialize(
    PoolTokenConfig calldata config,
    string calldata name,
    string calldata symbol,
    uint8 decimals,
    bytes calldata params
  ) external override initializerRunAlways(TOKEN_REVISION) {
    _initializeERC20(name, symbol, decimals);
    if (!isRevisionInitialized(TOKEN_REVISION)) {
      _initializeDomainSeparator();
    }
    _treasury = config.treasury;
    _initializePoolToken(config, name, symbol, decimals, params);
  }
}