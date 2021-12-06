// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract VIBES is ERC20 {

    constructor () ERC20("VIBES", "VIBES") {
        _mint(msg.sender, 21000000000 * (10 ** uint256(decimals())));
    }
}