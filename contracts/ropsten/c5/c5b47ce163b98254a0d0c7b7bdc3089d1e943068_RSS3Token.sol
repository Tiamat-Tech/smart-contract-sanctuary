// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RSS3Token is ERC20 {
    constructor(address to) ERC20("RSS3 Token", "RSS3") {
        _mint(to, 10 * 10 ** 8 * 10 ** 18);
    }
}