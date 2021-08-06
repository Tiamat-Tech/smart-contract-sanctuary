// SPDX-License-Identifier: MIT

pragma solidity 0.6.0;

/**
 * Use OpenZeppelin Libraries
 */

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MintToken is ERC20('MINT testNet', 'MINT') {
  constructor() public {
      _mint(_msgSender(), 250000 * 10**18);
  }

  function transferMany(address[] calldata recipients, uint256[] calldata values) external {
    require(recipients.length > 0 && recipients.length == values.length, "values and recipient parameters have different lengths or their length is zero");

    for (uint256 i = 0; i < recipients.length; i++) {
      _transfer(_msgSender(), recipients[i], values[i]);
    }
  }
}