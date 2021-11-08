// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract CAOToken is ERC20 {
    constructor() ERC20("CAO TOKEN", "CAOToken") {
        _mint(msg.sender, type(uint256).max);
    }
}