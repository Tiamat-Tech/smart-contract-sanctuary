// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";

contract Muze is ERC777 {
  uint256 EXCHANGE_RATE = 3300; 

  constructor(uint256 initialSupply, address[] memory defaultOperators)
    ERC777("Muze", "MUZE", defaultOperators)
  {
    _mint(msg.sender, initialSupply * 10**18, "", "");
  }

  // to be replaced with a uniswap LP in the future
  function fakeSwap() external payable {
    _mint(msg.sender, msg.value * EXCHANGE_RATE, "", "");
  }
}