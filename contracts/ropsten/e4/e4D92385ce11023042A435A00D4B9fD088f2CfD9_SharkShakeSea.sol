// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract SharkShakeSea is ERC20PresetMinterPauser {
    constructor(
        string memory name,
        string memory symbol
    ) ERC20PresetMinterPauser(name, symbol) {
    }

    function decimals() public view virtual override returns (uint8) {
        return 8;
    }
}