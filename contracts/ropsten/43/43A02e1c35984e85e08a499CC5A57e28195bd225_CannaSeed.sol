// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CannaSeed is ERC20('CannaSeed', 'CS') {
    constructor () {
        _mint(msg.sender, 1124200000000000000000000000);
    }
}