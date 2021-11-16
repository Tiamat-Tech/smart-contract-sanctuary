//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './interfaces/IEgg.sol';

contract Egg is ERC20, IEgg {
  address private _ants;

  constructor(address __ants) ERC20('EGG', 'EGG') {
    _ants = __ants;
  }

  function mint(address _to, uint256 _amount) external override onlyAntsContract {
    _mint(_to, _amount);
  }

  function burn(address _account, uint256 _amount) external override onlyAntsContract {
    _burn(_account, _amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }

  modifier onlyAntsContract() {
    if (msg.sender != _ants) revert Unauthorized();
    _;
  }
}