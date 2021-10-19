// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol"; // OZ contracts ^4.2

string constant NAME = "SOLAR token";
string constant SYMBOL = "SOLAR";
uint8 constant DECIMALS = 5;

contract SolarToken is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser(NAME, SYMBOL) {
        uint256 initialSupply = 100 * 1000 * 1000 * (uint256(10)**decimals());
        _mint(msg.sender, initialSupply);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}