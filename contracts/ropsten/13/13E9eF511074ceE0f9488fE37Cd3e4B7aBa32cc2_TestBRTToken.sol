// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "./whitelist/LGEWhitelisted.sol";

contract TestBRTToken is ERC20PresetFixedSupply, LGEWhitelisted {
    constructor()
        ERC20PresetFixedSupply(
            "Test BRT Token",
            "TestBRT",
            200000000 * 10**decimals(),
            msg.sender
        )
    {}

    // Hook into openzeppelin's flow to support LP whitelist
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        LGEWhitelisted._applyLGEWhitelist(from, to, amount);
        super._beforeTokenTransfer(from, to, amount);
    }
}