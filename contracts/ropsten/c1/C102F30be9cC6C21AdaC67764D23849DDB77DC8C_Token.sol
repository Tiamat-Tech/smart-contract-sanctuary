//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";

// TODO: USE ZEPPLIN FOR ERC20 TOKEN
/*
OpenZeppelin Contracts features a stable API, which means your contracts won’t break unexpectedly when upgrading to a newer minor version.
*/
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
An ERC20 token contract keeps track of fungible tokens: any one token is exactly equal to any 
other token; no tokens have special rights or behavior associated with them. 
This makes ERC20 tokens useful for things like a medium of exchange currency, voting rights, staking, and more.

Fungible goods are equivalent and interchangeable, like Ether, fiat currencies, and voting rights.
Non-fungible goods are unique and distinct, like deeds of ownership, or collectibles.

when dealing with non-fungibles (like your house) you care about which ones you have, while in fungible assets 
(like your bank account statement) what matters is how much you have.
*/
// THIS IS A MOCK TOKEN
// token for lottery
// for testing
contract Token is ERC20 {
  constructor(uint256 initialSupply) public ERC20("Gold", "GLD") {
    _mint(msg.sender, initialSupply);
  }

  // _ means private
  // _mint(address account, uint256 amount)
  // to allow ppl to call it we make this function
  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }

  event WinnerPicked(address indexed owner, address indexed spender, uint256 value);
}