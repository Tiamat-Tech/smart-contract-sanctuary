// SPDX-License-Identifier: NONLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract mockToken is ERC20 {
    constructor() ERC20("mockToken", "MT20") {
        _mint(msg.sender, 100 );
    }

    function mintTokens(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}