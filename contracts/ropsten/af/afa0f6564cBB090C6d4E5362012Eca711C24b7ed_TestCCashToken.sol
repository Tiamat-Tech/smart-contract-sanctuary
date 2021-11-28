//SPDX-License-Identifier: MIT
pragma solidity >=0.7.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestCCashToken is ERC20 {
    uint constant INITIAL_SUPPLY = 10000 * (10**18);
    constructor() ERC20("TestCCashToken", "TCT") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}