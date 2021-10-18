// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract SomeToken is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("SomeToken", "ST") public {}
}