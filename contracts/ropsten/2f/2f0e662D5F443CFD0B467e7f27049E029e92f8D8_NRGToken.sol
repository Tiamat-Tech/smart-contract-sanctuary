// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NRGToken is ERC20 {
    constructor() ERC20("NRG", "ENERGY") {
        _mint(msg.sender, 1000000 * 1000000000000000000);
    }
}