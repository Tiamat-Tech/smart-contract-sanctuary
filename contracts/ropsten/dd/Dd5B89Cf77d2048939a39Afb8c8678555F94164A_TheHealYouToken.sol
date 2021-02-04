// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TheHealYouToken is ERC20 {
    constructor() public ERC20("The Heal You", "HYTOKEN") {
        _setupDecimals(8);
        _mint(msg.sender, 4894522000000040000000);
    }
}