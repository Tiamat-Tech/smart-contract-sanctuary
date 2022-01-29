// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract KittyCoin is Ownable, ERC20Capped{
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 cap
        ) ERC20(name, symbol) ERC20Capped(cap){
        _mint(_msgSender(), initialSupply * (10**18));
    }
    function mint(address user, uint256 amount) public onlyOwner(){
    _mint(user, amount);
}}