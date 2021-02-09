// contracts/TheHealYouToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TheHealYouToken is ERC20 {
    constructor() public ERC20("The Heal You Network", "HYTOKEN") {
        _setupDecimals(8);
        _mint(msg.sender, 1000000000*(10 ** 8));
    }
}