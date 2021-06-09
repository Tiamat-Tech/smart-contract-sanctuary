pragma solidity 0.5.16;

import '@openzeppelin/contracts/token/ERC20/ERC20Mintable.sol';

contract wAKT is ERC20Mintable {
       string public name = "Wrapped Akash Token";
       string public symbol = "wAKT";
       uint8 public decimals = 18;
}