// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract TestEToken is ERC20PresetFixedSupply {
    constructor()
        ERC20PresetFixedSupply(
            "TestE Token",
            "TestE",
            200000000 * 10**decimals(),
            msg.sender
        )
    {}

}