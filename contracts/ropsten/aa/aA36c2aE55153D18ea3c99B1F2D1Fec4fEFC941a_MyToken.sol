// contracts/GLDToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("nanotech token", "NTT") {
        _mint(msg.sender, 10**26);
    }
}