//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './IEgg.sol';

contract Egg is ERC20, IEgg, Ownable {
  constructor(address cryptoAnts) ERC20('EGG', 'EGG') {
    transferOwnership(cryptoAnts);
  }

  function mint(address to, uint256 amount) external override onlyOwner {
    _mint(to, amount);
  }

  function burn(address account, uint256 amount) external override onlyOwner {
    _burn(account, amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
}