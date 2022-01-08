// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract Boba is ERC20('AIR', 'AIR'), Ownable {
  function mint(address _to, uint256 _amount) public virtual {
    _mint(_to, _amount);
  }


  

  function burn(address _from, uint256 _amount) public virtual {
    _burn(_from, _amount);
  }
}