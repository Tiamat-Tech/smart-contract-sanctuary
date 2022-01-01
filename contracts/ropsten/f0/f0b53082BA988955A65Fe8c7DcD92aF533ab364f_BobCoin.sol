// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BobCoin is ERC20 {
    constructor() ERC20("BobCoin", "BC") {  
        _mint(msg.sender, 10 * 10 ** decimals());
    }
}