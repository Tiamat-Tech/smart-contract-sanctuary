// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SuperToken is ERC20 {
    constructor() ERC20("Suoer", "SPR") {
        _mint(msg.sender, 1000000000000000000000000);
    }
}