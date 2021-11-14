// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";
import "@openzeppelin/[email protected]/token/ERC20/extensions/ERC20Burnable.sol";

/// @custom:security-contact [email protected]
contract TENCAR is ERC20, ERC20Burnable {
    constructor() ERC20("TENCAR", "TEN") {
        _mint(msg.sender, 101010 * 10 ** decimals());
    }
}