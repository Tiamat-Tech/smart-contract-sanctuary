// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
//how to deploy smart contract on ropsten network using truffle framework
import  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import  "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import  "@openzeppelin/contracts/access/Ownable.sol";
import  "@openzeppelin/contracts/utils/math/SafeMath.sol";
import  "@openzeppelin/contracts/security/Pausable.sol";

abstract contract PausableToken is ERC20,Pausable,Ownable {

  function transfer(address _to, uint256 _value) public whenNotPaused override  returns (bool) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused override returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public whenNotPaused override returns (bool) {
    return super.approve(_spender, _value);
  }

  function increaseApproval(address _spender, uint _addedValue) public whenNotPaused  returns (bool success) {
    return super.increaseAllowance(_spender, _addedValue);
  }

  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused  returns (bool success) {
    return super.decreaseAllowance(_spender, _subtractedValue);
  }
  
  function mint(address account, uint256 amount) public whenNotPaused onlyOwner {
     _mint(account,amount);
  }
  
  function burn(address account, uint256 amount) public whenNotPaused  {
     _burn(account,amount);
  }

}



contract PrinceToken is PausableToken{

    constructor() ERC20("PrinceToken","PNX") {
       
    }
}