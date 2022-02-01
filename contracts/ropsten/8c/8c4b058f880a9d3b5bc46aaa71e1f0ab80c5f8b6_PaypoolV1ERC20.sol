// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PaypoolV1ERC20 is ERC20 {
    constructor() ERC20("Paypool", "TBD") {
        _mint(msg.sender, 1000 * 10 ** 18);
    }
}