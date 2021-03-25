// SPDX-License-Identifier: MIT
pragma solidity ^0.7.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UniweeksToken is ERC20 {
    
    /**
        Create an ERC20 token that has the given initial supply using the open zepplin auditied erc20 contracts    
     */
    constructor(uint256 initialSupply) ERC20("Uniweeks Token", "UNIWKS") {
        _mint(msg.sender, initialSupply);
    }
}