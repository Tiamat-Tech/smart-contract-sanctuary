// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract LibraryToken is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("Library Token", "LIB") {}
}