// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol"; 

contract QuokkaCoin is ERC20 {
    uint256 _totalSupply = 1000000000000000000000000; // 1 million tokens
    constructor() ERC20("Quokka Token", "QOK", 18) {
        _mint(msg.sender, _totalSupply);
    }
}