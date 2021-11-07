// contracts/TunaToken.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract TunaToken is ERC20 {
    constructor() ERC20("TunaToken", "TUNA") {
        _mint(msg.sender, 20000000 * 10 ** decimals());
    }
}