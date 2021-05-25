// SPDX-License-Identifier: MIT
pragma solidity =0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(uint256 supply) ERC20("TestToken", "TTT") {
        _mint(msg.sender, supply);
    }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}