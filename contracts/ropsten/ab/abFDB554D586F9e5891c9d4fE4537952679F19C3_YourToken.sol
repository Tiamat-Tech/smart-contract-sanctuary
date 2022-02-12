//SPDX-License-Identifier:MIT
pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// learn more: https://docs.openzeppelin.com/contracts/3.x/erc20

contract YourToken is ERC20 {
    //ToDo: add constructor and mint tokens for deployer,
    //you can use the above import for ERC20.sol. Read the docs ^^^

    constructor() ERC20("Your Token","YTK") {
        _mint(msg.sender,1000*10**18);
    }
}