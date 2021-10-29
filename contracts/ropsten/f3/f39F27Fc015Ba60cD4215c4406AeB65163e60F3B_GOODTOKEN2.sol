// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GOODTOKEN2 is ERC20 {
    constructor() ERC20("GOODTOKEN2", "GOODT2") {
        _mint(msg.sender, 100000000000 * 10 ** decimals());
    }
}