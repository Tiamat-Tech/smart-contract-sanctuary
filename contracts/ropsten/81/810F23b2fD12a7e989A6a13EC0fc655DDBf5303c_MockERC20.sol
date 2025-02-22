// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockERC20", "TEST") {}

    function mint(uint256 amount) external {
        _mint(_msgSender(), amount);
    }
}