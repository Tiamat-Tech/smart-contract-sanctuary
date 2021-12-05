//SPDX-License-Identifier: MIT
pragma solidity >=0.7.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20Token is ERC20 {
    uint constant INITIAL_SUPPLY = 10000 * (10**18);
    constructor() ERC20("TestERC20Token", "TERC20T") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}