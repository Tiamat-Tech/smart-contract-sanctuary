// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CostaCoin is ERC20 {
    constructor() ERC20("CostaCoin", "CoCo") {
        // we mint only 100 tokens
        _mint(msg.sender, 100 * 10**uint(decimals()));
    }
}