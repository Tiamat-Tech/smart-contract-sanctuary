// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract RedCatCoin is ERC20PresetFixedSupply {
    constructor() ERC20PresetFixedSupply("RedCat Coin", "RCC", (10**8) * (10**18), msg.sender) {}
}