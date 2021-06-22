// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol)
    {
        uint256 initialSupply = 10 ** 2 * 10 ** uint256(decimals());
        _mint(msg.sender, initialSupply);
    }
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}