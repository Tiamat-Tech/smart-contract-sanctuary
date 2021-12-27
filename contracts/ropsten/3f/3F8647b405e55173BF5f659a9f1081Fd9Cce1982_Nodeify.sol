//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Nodeify is ERC20 {
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name = "Nodeify";
    string private _symbol = "NODE";
    uint8 private _decimals = 18;

    constructor() ERC20(_name, _symbol){
        _mint(msg.sender, 10**18);
    }

}