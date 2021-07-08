// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20Burnable.sol";

contract SAUNALAND is ERC20, ERC20Burnable {
    constructor() ERC20("SAUNALAND", "SAUNA") {
        _mint(msg.sender, 2760000 * 10 ** decimals());
    }
}