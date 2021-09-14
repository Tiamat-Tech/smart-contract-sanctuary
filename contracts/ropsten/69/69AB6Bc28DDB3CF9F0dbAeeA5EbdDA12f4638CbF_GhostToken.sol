// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./token/presets/ERC20PresetMinterPauser.sol";

// GHOST ERC20 token contract
contract GhostToken is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("GHOST", "GHST", 18) {}
}