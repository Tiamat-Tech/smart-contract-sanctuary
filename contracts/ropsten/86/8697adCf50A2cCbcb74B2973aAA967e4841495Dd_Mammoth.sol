// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Mammoth is ERC20 {
    constructor() ERC20("Mammoth", "MMM") {
        _mint(msg.sender, 1e24);
    }
}