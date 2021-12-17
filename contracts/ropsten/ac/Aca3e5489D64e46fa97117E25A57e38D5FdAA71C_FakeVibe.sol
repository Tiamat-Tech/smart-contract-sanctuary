// contracts/FakeVibe.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";

contract FakeVibe is ERC20 {
    constructor(uint256 initialSupply) ERC20("FakeVibe", "FVIB") {
        _mint(msg.sender, initialSupply);
    }
}