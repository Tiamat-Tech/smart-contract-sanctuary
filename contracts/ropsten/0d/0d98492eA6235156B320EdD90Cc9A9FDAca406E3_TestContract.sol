// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestContract is ERC20 {
    constructor() ERC20("TestContract", "TEST") {
        _mint(msg.sender, 20000 * 10 ** decimals());
    }

    function faucet(address to, uint256 amount) external {
        require(amount < 5000 * 10 ** decimals());
        _mint(to, amount);
    }
}