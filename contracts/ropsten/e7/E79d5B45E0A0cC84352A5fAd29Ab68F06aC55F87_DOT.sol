// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DOT is ERC20 {
    constructor(uint256 _initialSupply) ERC20("DOT", "DOT") {
        _mint(msg.sender, _initialSupply);
    }
}