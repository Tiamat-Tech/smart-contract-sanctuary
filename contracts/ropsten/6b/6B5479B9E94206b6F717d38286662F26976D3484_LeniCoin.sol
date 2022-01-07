//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract LeniCoin is ERC20 {
    uint256 TOTAL_SUPPLY = 10000000000000000000000;

    constructor() ERC20("LENI", "LeniCoin") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}