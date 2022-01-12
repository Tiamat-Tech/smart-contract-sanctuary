// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract DinoEggs is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("DinoEggs", "EGGS") {}
}