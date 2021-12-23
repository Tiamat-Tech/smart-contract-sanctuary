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
    mint(1*(10**30));
  }

  function mint(uint256 _amount) onlyOwner public {
    _mint(_msgSender(),_amount);
  }

  function burn(uint256 _amount) onlyOwner public {
      _burn(owner, _amount);
  }

  function transfer(address _receipient,uint256 _amount) override virtual public returns(bool) {
    _transfer(_msgSender(),_receipient,_amount);
    return true;
  }

  function transferFrom(address _sender,address _receipient,uint256 _amount)public override virtual returns(bool){
    require(_sender==_msgSender(),"Sender is not the caller");
      _transfer(_sender,_receipient,_amount);
      return true;
  }
}