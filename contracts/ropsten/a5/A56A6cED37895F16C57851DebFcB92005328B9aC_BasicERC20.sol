// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BasicERC20 is ERC20{

    constructor () ERC20("BASIC1", "BAS") {
        _mint(msg.sender, 10000000 * (10 ** uint256(decimals())));
    }

}