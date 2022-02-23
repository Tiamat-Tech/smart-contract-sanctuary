// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract Odo is ERC20PresetFixedSupply {
    constructor() ERC20PresetFixedSupply ("Odo", "ODO", 10000000000 * 10**18, 0x88A14AF453b14070B9B943eea32bf3F534dFa01a) {}
}