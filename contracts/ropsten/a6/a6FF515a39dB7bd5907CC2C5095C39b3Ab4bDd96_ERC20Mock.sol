// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20('ERC20M', 'ERC20Mock') {
    constructor () {
        _mint(msg.sender, 2 ** 256 - 1);
    }
}