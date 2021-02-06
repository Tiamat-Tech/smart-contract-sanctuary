// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';


contract NotABank is ERC20 {
    constructor() public ERC20("Not A Bank", "NAB") {
        _mint(msg.sender, 100000000000000000000000);
    }
}