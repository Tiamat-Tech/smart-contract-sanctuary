//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/*
  Egg token
 */
contract Egg is ERC20, ERC20Burnable, Ownable {
  address private _ants;

  constructor(address _exchange) ERC20('Egg', 'EGG') {
    transferOwnership(_exchange);
  }

  /*
    Mints and approves the exchange to spend the tokens
   */
  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
    _approve(to, owner(), amount);
  }

  /*
    Burns the tokens from the given address, specially useful for the exchange.
   */
  function burn(address from, uint256 amount) public onlyOwner {
    super.burnFrom(from, amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
}