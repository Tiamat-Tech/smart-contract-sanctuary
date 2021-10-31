// SPDX-License-Identifier: MIT
// vim: noai:ts=4:sw=4

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

contract MorphwareToken is ERC20, ERC20Burnable {
    constructor() ERC20("MorphwareToken", "MWT") {
        _mint(msg.sender, 1232922769 * 10 ** decimals());
    }
}