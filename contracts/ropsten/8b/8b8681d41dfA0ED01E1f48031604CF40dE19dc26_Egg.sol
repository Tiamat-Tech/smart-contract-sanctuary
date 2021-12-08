//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;


import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
}



contract Egg is ERC20, IEgg, Ownable, ReentrancyGuard {
  using SafeMath for uint256;
  address private _owner;
  

  constructor(address __ants) ERC20('HUE', 'HUE') {
    
    _owner = __ants;
  }

  function mint(address _to, uint256 _amount) external override {
    
    require(msg.sender == _owner, 'Only the ants contract can call this function');
    _mint(_to, _amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
  
  
}