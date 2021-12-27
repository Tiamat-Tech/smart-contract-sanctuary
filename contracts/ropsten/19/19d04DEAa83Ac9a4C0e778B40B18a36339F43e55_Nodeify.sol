//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Nodeify is ERC20 {
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    string private _name = "Nodeify";
    string private _symbol = "NODE";

    constructor(uint256 initialSupply) ERC20(_name, _symbol){
        _mint(msg.sender, initialSupply);
    }

}