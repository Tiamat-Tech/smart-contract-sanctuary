// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AGROToken is ERC20 {
    uint8 internal constant DECIMALS = 6;
    uint256 internal constant ZEROES = 10**DECIMALS;

    uint256 internal constant TOTAL_SUPPLY = 575000000 * 10**6 * ZEROES;

    constructor(address payable _manager) ERC20("Aggressive", "AGRO") {
        _mint(_manager, TOTAL_SUPPLY);
    }
}