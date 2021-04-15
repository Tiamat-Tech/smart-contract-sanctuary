pragma solidity ^0.5.0;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';

contract TestToken is ERC20 {
  string public name = 'Test Token';
  string public symbol = 'TST';
  uint8 public decimals = 0;
  uint constant public INITIAL_SUPPLY = 10000000;

  constructor() public {
    _mint(msg.sender, INITIAL_SUPPLY);
  }
}