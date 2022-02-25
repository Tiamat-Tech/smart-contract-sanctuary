//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(uint256 initialSupply) ERC20("MOCK ERC20", "MCK") {
        _mint(msg.sender, initialSupply);
    }
}