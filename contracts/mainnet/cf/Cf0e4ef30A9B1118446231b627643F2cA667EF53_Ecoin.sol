// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Ecoin is ERC20("Ecoin chain token", "ECOIN"), Ownable {
    constructor() {
        _mint(msg.sender, 3800000000 * 1e18);
    }
}