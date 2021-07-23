// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockLP is ERC20 {
    constructor() ERC20("LP", "LP") {
        _mint(msg.sender, 1 * 10**18);
    }
}