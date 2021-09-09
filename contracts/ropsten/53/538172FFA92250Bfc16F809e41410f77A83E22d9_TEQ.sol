// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TEQ is ERC20, Ownable {
    constructor() ERC20("TEQ", "TEQ") {}
    
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}