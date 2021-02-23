//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DanToken is ERC20 {
    constructor(uint256 initialSupply) public ERC20("DanToken", "DAN") {
        _mint(msg.sender, initialSupply);
    }
}