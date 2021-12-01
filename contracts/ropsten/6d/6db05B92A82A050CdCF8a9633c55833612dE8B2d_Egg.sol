import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import './IEgg.sol';

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

/**
 * @dev ERC20 implentation with no decimals (indivisible) that represents ants eggs.
 */
contract Egg is ERC20, IEgg {
  address private _cryptoAntsAddress;

  constructor(address _ants) ERC20('EGG', 'EGG') {
    _cryptoAntsAddress = _ants;
  }

  /**
   * @dev See {IERC20-mint}.
   */
  function mint(address _to, uint256 _amount) external override {
    //solhint-disable-next-line
    require(msg.sender == _cryptoAntsAddress, 'Only the ants contract can call this function, please refer to the ants contract');
    _mint(_to, _amount);
  }

  /**
   * @dev See {IERC20-decimals}.
   */
  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
}