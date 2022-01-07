//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract Token is ERC20PresetFixedSupply {
  constructor(
    string memory name,
    string memory symbol,
    uint256 initialSupply,
    address owner
  )
    ERC20PresetFixedSupply(name, symbol, initialSupply, owner)
  // solhint-disable-next-line no-empty-blocks
  {

  }
}