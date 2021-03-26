// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract MockERC20 is ERC20Burnable {
    constructor(uint256 supply) public ERC20("Mock ERC20", "ERC20") {
        _mint(msg.sender, supply);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}