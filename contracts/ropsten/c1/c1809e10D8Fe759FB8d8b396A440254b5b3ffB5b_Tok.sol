/**
 *Submitted for verification at BscScan.com on 2022-01-17
 */
// SPDX-License-Identifier: MIT

pragma solidity 0.8.7; 

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol" ;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol" ; 
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol" ;

contract Tok is Initializable , ERC20Upgradeable , OwnableUpgradeable   { 

     function initialize() external initializer{ 
         __ERC20_init("Token" , "TOK");
         __Ownable_init() ; 
     }  

    function mint(address to , uint amount) external onlyOwner{
        _mint(to , amount) ;  
    }
    
    
}