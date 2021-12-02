//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './IEgg.sol';

contract Egg is ERC20, IEgg {
  address private _ants;

  constructor(address _adr) ERC20('EGG', 'EGG') {
    _ants = _adr;
  }

  function mint(address account, uint256 amount) external override {
    //solhint-disable-next-line
    if (msg.sender != _ants) revert EggsUnauth();
    _mint(account, amount);
  }

  function burn(address account, uint256 amount) external override {
    if (msg.sender != _ants) revert EggsUnauth();
    _burn(account, amount);
  }

  function decimals() public view virtual override(IEgg, ERC20) returns (uint8) {
    return 0;
  }
}