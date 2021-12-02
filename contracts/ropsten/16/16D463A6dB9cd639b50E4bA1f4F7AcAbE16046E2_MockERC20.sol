// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockERC20 is Context, ERC20 {

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
    }
    
    function mint(uint256 amount, address recipient) public {
        _mint(recipient, amount);
    }
}