// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC20/ERC20.sol";

contract YunCoin is ERC20 {
    constructor() ERC20("YunCoin", "YUN") {
        _mint(msg.sender, 69420 * 10 ** decimals());
    }
}