//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MERC20 is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 amount
    ) ERC20(name, symbol) {

        _mint(owner(), amount);

    }
}