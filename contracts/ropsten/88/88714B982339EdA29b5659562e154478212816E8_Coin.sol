// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Coin is ERC20 {
    constructor(uint256 initialSupply) ERC20("2Coin", "2COIN") {
        _mint(msg.sender, initialSupply * 10**decimals());
    }
}