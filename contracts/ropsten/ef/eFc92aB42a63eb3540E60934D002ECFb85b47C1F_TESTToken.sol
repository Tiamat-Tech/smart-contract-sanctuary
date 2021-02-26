// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//import "../../openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "../../openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract TESTToken is ERC20Burnable {
    //total fixed supply of 140,736,000 tokens.

    constructor () ERC20("Test Protocol", "TEST") {
        super._mint(msg.sender, 140736000 ether);
    }
}