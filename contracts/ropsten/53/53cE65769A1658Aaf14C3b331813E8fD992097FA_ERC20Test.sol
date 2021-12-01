// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ERC20 Token that let every body mint tokens for test
contract ERC20Test is ERC20("Test Token", "TST") {
    constructor() {
        _mint(msg.sender, 100000 * 10**18); // mint 100k tokens to owner
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}