// SPDX-License-Identifier: MIT
pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
   constructor () ERC20("MyToken", "MTN") {
      _setupDecimals(0);
      _mint(msg.sender, 1000000);
   }
}