//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.3;

import "hardhat/console.sol";
import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract TestUSDT is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("Test USDT", "USDT") {}
}