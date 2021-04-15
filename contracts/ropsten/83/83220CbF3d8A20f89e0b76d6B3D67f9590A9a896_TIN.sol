pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';

contract TIN is ERC20 {
  string public name = 'Digital Governance Token';
  string public symbol = 'TIN';
  uint8 public decimals = 0;
  uint constant public INITIAL_SUPPLY = 20000000;

  constructor() public {
    _mint(msg.sender, INITIAL_SUPPLY);
  }
}