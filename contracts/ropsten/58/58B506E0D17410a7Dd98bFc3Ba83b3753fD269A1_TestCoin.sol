// contracts/TestCoin.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestCoin is ERC20 {
    constructor(uint256 initialSupply) ERC20("TEST Coin", "TSTC") {
        _mint(msg.sender, initialSupply);
    }

    function decimals() override public pure returns (uint8) {
        return 6;
    }
}