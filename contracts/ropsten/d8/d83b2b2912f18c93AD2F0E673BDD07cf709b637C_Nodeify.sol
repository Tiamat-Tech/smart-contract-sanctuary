//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Nodeify is ERC20 {
    string private _name = "Nodeify";
    string private _symbol = "NODE";

    constructor() ERC20(_name, _symbol){
        _mint(msg.sender, 500000000000000000000000); // 500k
    }

}