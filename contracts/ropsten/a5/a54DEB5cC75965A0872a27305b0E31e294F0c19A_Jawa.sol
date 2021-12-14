// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Jawa is ERC20 {
    constructor() ERC20("JAWA", "JAWA") {
        _mint(msg.sender, 10000 * 10**decimals());
    }
}