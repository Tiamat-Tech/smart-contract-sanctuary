//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20{


     address public owner; 
     bool private enable;

    constructor(string memory _tokenName , string memory _tokenSymbol)ERC20(_tokenName,_tokenSymbol){
        owner = msg.sender;
    }

    modifier onlyOwner{
        require(_msgSender() == owner,"THIS FUNCTION ONLY WORKS FOR OWNER");
        _;    
    } 

    function changeBool() public onlyOwner {
        enable = !enable;
    }

    

}