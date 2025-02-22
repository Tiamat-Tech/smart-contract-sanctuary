// contracts/FakeEth.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC20.sol";

contract FakeEth is ERC20 {
    constructor(uint256 initialSupply) ERC20("FakeEth", "FETH") {
        _mint(msg.sender, initialSupply);
    }
}