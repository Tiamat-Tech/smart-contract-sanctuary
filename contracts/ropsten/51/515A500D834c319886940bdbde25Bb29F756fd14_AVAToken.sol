// contracts/AVAToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AVAToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Ava", "AVA") {
        _mint(msg.sender, initialSupply);
    }
}