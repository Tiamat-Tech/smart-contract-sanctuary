// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20{
    constructor() ERC20("testtoken", "tt") public
    {
        _mint(address(msg.sender), 1000000 * 10**18);
    }
}