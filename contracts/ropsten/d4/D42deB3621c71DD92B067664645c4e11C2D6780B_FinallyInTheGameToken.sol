// contracts/FigaToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";

contract FinallyInTheGameToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("FinallyInTheGameToken", "FIGA") {
        _mint(msg.sender, initialSupply);
    }
}