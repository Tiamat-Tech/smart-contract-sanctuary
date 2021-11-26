// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.6.12;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract ParallelBridgeToken is ERC20PresetMinterPauser {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public ERC20PresetMinterPauser(name, symbol) {
        _setupDecimals(decimals);
    }
}