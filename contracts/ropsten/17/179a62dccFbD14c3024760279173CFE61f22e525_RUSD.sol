//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RUSD is ERC20 {
  using SafeMath for uint256;

  address public owner ;

   modifier onlyOwner() {
    require(_msgSender()==owner,"owner is not the caller");
    _;
  }

  constructor() ERC20("Reflect USD","RUSD"){
      owner = _msgSender();
    mint(_msgSender(), 1*(10**30));
  }

  function mint(address _recepient,uint256 _amount) onlyOwner public {
    _mint(_recepient,_amount);
  }

  function burn(uint256 _amount) onlyOwner public {
      _burn(owner, _amount);
  }

}