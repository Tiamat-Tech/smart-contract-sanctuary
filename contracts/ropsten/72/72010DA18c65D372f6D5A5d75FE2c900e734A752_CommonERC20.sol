// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './token/ERC20/presets/ERC20PresetMinterPauser.sol';

contract CommonERC20 is ERC20PresetMinterPauser {
    using Strings for uint256;

    constructor(
        string memory name,
        string memory symbol
        ) ERC20PresetMinterPauser(name, symbol){}
}