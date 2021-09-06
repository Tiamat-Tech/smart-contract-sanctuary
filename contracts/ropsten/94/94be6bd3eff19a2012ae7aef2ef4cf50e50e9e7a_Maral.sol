// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol' ;
import 'https://github.com/OpenZeppelin/openzeppelin-contracts/blob/f1e92dd184a599f39ce9cc4ec8a5e4a94416f3a2/contracts/utils/math/SafeMath.sol';


contract Maral is ERC20 {
using SafeMath for uint256;
uint BURN_FEE = 5;
uint TAX_FEE = 5;
address public owner;
mapping (address => bool) public exclidedFromTax;

constructor() public ERC20('Maral' ,'MARA' ) {
_mint(msg.sender, 1000* 10 ** 18);
owner = msg.sender;
exclidedFromTax[msg.sender] = true;

}

function transfer(address recipient, uint256 amount) public override returns (bool)  {
if (exclidedFromTax[msg.sender] == true) {
_transfer(_msgSender(), recipient,amount);
} else {
uint burntAmount = amount.mul(BURN_FEE) / 100;
uint adminAmount = amount.mul(TAX_FEE) / 100;
_burn(_msgSender(), burntAmount);
_transfer(_msgSender(), owner, adminAmount);
_transfer(_msgSender(), recipient, amount.sub(burntAmount).sub(adminAmount));
}
return true;
  }



}