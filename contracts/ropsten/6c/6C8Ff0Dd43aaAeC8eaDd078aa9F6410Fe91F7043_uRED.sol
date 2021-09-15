// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract uRED is ERC20 {

    constructor() ERC20("100 Rainbows", "RED") {
        _mint(msg.sender, 174778761 * (10 ** uint256(decimals())));
    }
}