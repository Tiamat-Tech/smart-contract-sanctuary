// SPDX-License-Identifier: MIT
pragma solidity =0.7.4;

import "./erc20permit/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract TESTToken is ERC20Permit, ERC20Burnable {
    //total fixed supply of 140,736,000 tokens.

    constructor () ERC20Permit("Test Protocol") ERC20("Test Protocol", "TEST") {
        super._mint(msg.sender, 140736000 ether);
    }
}