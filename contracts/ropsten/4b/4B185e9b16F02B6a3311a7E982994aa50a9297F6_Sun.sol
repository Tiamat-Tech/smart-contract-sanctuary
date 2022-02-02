// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Sun is ERC20 {
    string public _name = "SUN";
    string public _symbol = "SUN";
    constructor() public {
        _mint(msg.sender, 1000000);
    }
}