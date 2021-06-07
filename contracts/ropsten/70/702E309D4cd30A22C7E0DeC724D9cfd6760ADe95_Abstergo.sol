// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Abstergo is ERC20 {
    constructor() ERC20("Abstergo", "ATO") {
        _mint(msg.sender, 7000000000 * 18 ** decimals());
    }
}