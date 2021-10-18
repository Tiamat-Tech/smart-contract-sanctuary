// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Give is ERC20 {
    /*
    * Token contract
    * Donations.org token contract Give
    * with a total supply of 1.000.000.000 (one billion million) tokens
    */
    constructor() ERC20("Donations.org", "GIVE") {
        _mint(_msgSender(), 1000000000000000000000000000);
    }
}