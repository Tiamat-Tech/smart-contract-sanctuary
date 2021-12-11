//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Egg is ERC20, ERC20Burnable, Ownable {
  address private _ants;

  constructor(address _exchange) ERC20('Egg', 'EGG') {
    transferOwnership(_exchange);
  }

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
    _approve(to, owner(), amount);
  }

  function burn(address from, uint256 amount) public onlyOwner {
    super.burnFrom(from, amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
}