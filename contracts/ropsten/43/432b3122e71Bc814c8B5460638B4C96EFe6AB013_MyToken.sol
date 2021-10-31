// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MyToken is ERC20 {
    constructor() public ERC20("Duggie", "DUT") {
        _mint(msg.sender, 850000000 * (10 ** uint256(decimals())));
    }
}