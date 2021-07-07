// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20Burnable.sol";

contract NoobSaibot is ERC20, ERC20Burnable {
    constructor() ERC20("Noob Saibot", "NOOB") {
        _mint(msg.sender, 8999000100 * 10 ** decimals());
    }
}