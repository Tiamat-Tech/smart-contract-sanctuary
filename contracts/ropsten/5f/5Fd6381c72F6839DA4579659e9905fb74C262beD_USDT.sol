//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    constructor(uint256 supply) ERC20("USDT", "USDT") {
        _mint(msg.sender, supply);
    }
}