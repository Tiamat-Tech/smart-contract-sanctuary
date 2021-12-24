//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './interfaces/IEgg.sol';

/// @title Egg token contract (inherits ERC20)
contract Egg is ERC20, IEgg {
  address private immutable _ants;

  /// @dev Verify that only the ants contract can call this function
  modifier onlyAnts() {
    if (msg.sender != _ants) revert OnlyAnts();
    _;
  }

  /// @param ants CryptoAnts address
  constructor(address ants) ERC20('EGG', 'EGG') {
    if (ants == address(0)) revert ZeroAddress();
    _ants = ants;
  }

  /// @inheritdoc IEgg
  function mint(address to, uint256 amount) external override onlyAnts {
    _mint(to, amount);
  }

  /// @inheritdoc IEgg
  function burn(address owner, uint256 amount) external override onlyAnts {
    _burn(owner, amount);
  }

  /// @inheritdoc ERC20
  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
}