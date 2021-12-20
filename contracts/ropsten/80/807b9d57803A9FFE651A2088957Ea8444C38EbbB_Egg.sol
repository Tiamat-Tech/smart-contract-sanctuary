//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;


import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
  function burn(address, uint256) external;
  
}



contract Egg is ERC20, IEgg, Ownable, ReentrancyGuard {
  
  address private _ants;
  

  constructor(address __ants) ERC20('EGG', 'EGG') {
    
    _ants = __ants;
  }

  receive() external payable {}


  function mint(address _to, uint256 _amount) external override {
    
    require(msg.sender == _ants, 'Solo ant llama');
    _mint(_to, _amount);
  }

  function burn(address _account, uint256 _amount) external override onlyOwnerAnts {
    _burn(_account, _amount);
  }

  modifier onlyOwnerAnts() {
    require(msg.sender == _ants, 'Solo ant llama');
    _;
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
  
  
}