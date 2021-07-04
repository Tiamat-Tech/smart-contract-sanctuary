// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20Burnable.sol";

contract CHOWCOIN is ERC20, ERC20Burnable {
    constructor() ERC20("CHOW COIN", "CHOW") {
        _mint(msg.sender, 8600999000 * 10 ** decimals());
    }
}