// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KiToken is ERC20Burnable,Ownable {

constructor () ERC20("KI Token","KI")  {
    
}    

function mint(address _to, uint256 _amount) public onlyOwner {
  _mint(_to,_amount);  
}

}