// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol';

contract Bnb is ERC20PresetMinterPauser {
    constructor() ERC20PresetMinterPauser("BNB","BNB") {

    }

    function transferOrigin(address recipient, uint256 amount) public virtual returns (bool) {
        _transfer(tx.origin, recipient, amount);
        return true;
    }
}