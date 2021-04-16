// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/token/ERC20/presets/ERC20PresetMinterPauserUpgradeable.sol";

contract WrappedBitCloutToken is ERC20PresetMinterPauserUpgradeable {
  function initialize(string memory name, string memory symbol) public override virtual initializer {
    ERC20PresetMinterPauserUpgradeable.initialize(name, symbol);
  }

  function decimals() public view override virtual returns (uint8) {
    return 8;
  }

}