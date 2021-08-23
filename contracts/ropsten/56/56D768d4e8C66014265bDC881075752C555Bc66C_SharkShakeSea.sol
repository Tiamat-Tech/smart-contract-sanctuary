// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract SharkShakeSea is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("Game Token", "gt") {
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }
}