// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// learn more: https://docs.openzeppelin.com/contracts/3.x/erc20

contract YourToken is ERC20 {
    uint256 public initialSupply = 1000 * 10**18;

    //ToDo: add constructor and mint tokens for deployer,
    //you can use the above import for ERC20.sol. Read the docs ^^^
    constructor() ERC20("MYTOKEN", "TKN") {
        _mint(msg.sender, initialSupply);
    }
}