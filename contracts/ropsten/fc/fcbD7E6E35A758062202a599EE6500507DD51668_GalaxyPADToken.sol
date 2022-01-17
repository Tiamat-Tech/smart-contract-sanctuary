// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GalaxyPADToken is ERC20 {
    constructor() ERC20("GalaxyPADToken", "GPT") {
        _mint(msg.sender, 100000000000000 * 10 ** decimals());
    }
}