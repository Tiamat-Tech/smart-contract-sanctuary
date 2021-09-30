// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
import "./Operator.sol";
contract KiToken is ERC20Burnable,Operator {

constructor () ERC20("KI Token","KI")  {
    operators[_msgSender()]=true;
}    



function mint(address _to, uint256 _amount) public onlyOperator {
  _mint(_to,_amount);  
}

}