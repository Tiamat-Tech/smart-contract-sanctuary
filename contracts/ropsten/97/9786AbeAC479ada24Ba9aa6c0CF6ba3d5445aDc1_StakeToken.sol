// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.4;

import './SlashableStakeTokenBase.sol';
import './interfaces/StakeTokenConfig.sol';
import '../../tools/upgradeability/VersionedInitializable.sol';

contract StakeToken is SlashableStakeTokenBase, VersionedInitializable {
  uint256 private constant TOKEN_REVISION = 1;

  constructor() SlashableStakeTokenBase(zeroConfig(), 'STAKE_STUB', 'STAKE_STUB', 0) {}

  function zeroConfig() private pure returns (StakeTokenConfig memory) {}

  function initialize(
    StakeTokenConfig calldata params,
    string calldata name,
    string calldata symbol,
    uint8 decimals
  ) external virtual override initializer(TOKEN_REVISION) {
    super._initializeERC20(name, symbol, decimals);
    super._initializeToken(params);
    super._initializeDomainSeparator();
    emit Initialized(params, name, symbol, decimals);
  }

  function getRevision() internal pure virtual override returns (uint256) {
    return TOKEN_REVISION;
  }
}