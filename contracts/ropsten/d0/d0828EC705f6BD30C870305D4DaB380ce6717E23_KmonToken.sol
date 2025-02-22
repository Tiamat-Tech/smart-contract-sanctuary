//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract KmonToken is ERC20 {
    constructor() ERC20('KmonCoin', 'KMON') {
        _mint(msg.sender, 1000000000);
    }
}