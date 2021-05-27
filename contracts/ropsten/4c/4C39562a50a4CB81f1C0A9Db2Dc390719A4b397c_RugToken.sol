// contracts/RugToken.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import '@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20Capped.sol';

contract RugToken is ERC20PresetMinterPauser, ERC20Capped {    
    constructor(
        string memory name,
        string memory symbol,
        address owner
    ) public ERC20PresetMinterPauser(name, symbol) ERC20Capped(300000000*(10**18)) {
        _mint(owner, 300000000*(10**18));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20PresetMinterPauser, ERC20Capped) {
        super._beforeTokenTransfer(from, to, amount);
    }
}