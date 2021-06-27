pragma solidity ^0.8.3;
// SPDX-License-Identifier: Unlicensed
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract DocToken is ERC20 {
  constructor() ERC20('DocToken', 'DOCT') {
    _mint(msg.sender, 1000000 * 10 ** 18);
  }
}