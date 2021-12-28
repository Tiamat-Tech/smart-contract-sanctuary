// SPDX-License-Identifier: MIT
pragma solidity =0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract INRERC is ERC20 {
    constructor() ERC20("Indian rupee", "INR") {
        _mint(msg.sender, 1000 * 10 ** decimals());
    }
}