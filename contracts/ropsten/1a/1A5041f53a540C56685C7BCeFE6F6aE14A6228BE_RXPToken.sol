// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import '../node_modules/@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol';

contract RXPToken is ERC20PresetMinterPauser {
    uint8 public constant DECIMALS = 8;
    uint256 public constant INITIAL_SUPPLY = 500000000 * (10 ** uint256(DECIMALS)); // 500,000,000 tokens

    constructor () ERC20PresetMinterPauser('RXP Token', 'RXP') {
        _setupDecimals(8);
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}