// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Test2 is ERC20 {
    constructor() ERC20("Test2", "TS2") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }
}