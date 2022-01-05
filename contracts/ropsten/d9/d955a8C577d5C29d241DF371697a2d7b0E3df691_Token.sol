// contracts/Token.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    string constant NAME = "MET Token";
    string constant SYMBOL = "MET";
    uint256 constant TOTAL_SUPPLY = 500000000000000000000000000;

    constructor() ERC20(NAME, SYMBOL) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}