// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Coin is ERC20, Ownable {
    mapping(address => uint256) producer;

    constructor() ERC20("yhx 2021", "yhx") {
        _mint(msg.sender, 100e18);
    }
}