// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20Burnable.sol";

contract HungPony is ERC20, ERC20Burnable {
    constructor() ERC20("Hung Pony", "HUNG") {
        _mint(msg.sender, 7844782268 * 10 ** decimals());
    }
}