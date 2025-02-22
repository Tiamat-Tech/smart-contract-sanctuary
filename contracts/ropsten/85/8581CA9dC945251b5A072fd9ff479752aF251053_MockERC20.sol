/*

website: 


SPDX-License-Identifier: MIT

*/
pragma solidity 0.7.6;


import "../lib/ERC20.sol";


contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }
}