// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JonyCoin is ERC20 {
    constructor() ERC20("JonyCoin", "JOSC") {
        _mint(msg.sender, 180000000 * 10**decimals());
    }
}