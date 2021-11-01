//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Syntax is ERC20, Ownable {

    constructor(string memory name, string memory symbol, uint256 totalSupply)
        ERC20(name, symbol)
        {
            _mint(_msgSender(), totalSupply * 10** decimals());
        }
}