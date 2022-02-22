//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OddsCoin is ERC20 {
    constructor() ERC20("OddsCoin", "Odds") {
        _mint(msg.sender, 1000000000);
    }
}