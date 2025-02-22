// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
contract USDT is ERC20 {
    constructor() ERC20('USDT Test', 'USDT') {
       _mint(msg.sender, 100000000 * 10 ** 18);
    }
}