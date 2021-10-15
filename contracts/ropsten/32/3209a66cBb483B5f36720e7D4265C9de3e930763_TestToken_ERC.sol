// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken_ERC is ERC20 {

    constructor(string memory name, string memory symbol) payable ERC20(name, symbol) 
    {
        uint256 initialSupply = 100 ** 2 * 10 ** uint256(decimals());
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}