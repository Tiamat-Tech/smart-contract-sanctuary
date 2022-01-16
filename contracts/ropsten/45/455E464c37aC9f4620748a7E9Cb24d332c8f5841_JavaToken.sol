// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract JavaToken is ERC20 {
 string public constant _name = "Java Token";
 string public constant _symbol = "JVM";
 uint8 public constant _decimals = 18;
 uint256 public constant _totalSupply = 500*10**6*10**18;
 constructor () ERC20(_name, _symbol) {
       _mint(msg.sender, _totalSupply);
    }
}