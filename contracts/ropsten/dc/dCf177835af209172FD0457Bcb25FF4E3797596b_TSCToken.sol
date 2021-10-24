// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "./whitelist/TSCWhitelisted.sol";

contract TSCToken is ERC20PresetFixedSupply, TSCWhitelisted {
    constructor()
        ERC20PresetFixedSupply(
            "HAHA",
            "TSC",
            200000000*10**decimals(),
            msg.sender
        )
    {}

    // Hook into openzeppelin's flow to support LP whitelist
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        _applyTSCWhitelist(from, to, amount);
    }
}