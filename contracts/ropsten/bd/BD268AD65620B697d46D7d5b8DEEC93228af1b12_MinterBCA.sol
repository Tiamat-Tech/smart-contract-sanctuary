// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./TokenBCA.sol";


contract MinterBCA is TokenBCA {
   constructor(
       string memory _name,
       string memory _symbol,
       address owner) TokenBCA(_name, _symbol)  {
       _mint(owner, 100000000000E18);
   }
}