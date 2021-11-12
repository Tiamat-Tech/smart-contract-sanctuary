//SPDX-License-Identifier: Unlicense
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;

  function burn(address, uint256) external;
}

pragma solidity >=0.8.4 <0.9.0;

contract Egg is ERC20, IEgg {
  address private _ants;

  constructor(address __ants) ERC20('EGG', 'EGG') {
    _ants = __ants;
  }

  modifier onlyAntsContract() {
    /* solhint-disable reason-string */
    require(msg.sender == _ants, 'Only the ants contract can call this function, please refer to the ants contract');
    _;
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
}