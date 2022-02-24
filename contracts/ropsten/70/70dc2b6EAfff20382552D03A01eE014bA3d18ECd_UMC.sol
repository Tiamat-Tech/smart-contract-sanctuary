// contracts/URC.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UMC is ERC20 {
    constructor() ERC20("UMC", "UMC") {
        _mint(msg.sender, 5000 * (10**uint256(decimals())));
    }
}