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

    modifier isEnable{
        require(enable==false,"This function is not active currently");
        _;
    }

    function changeBool() public onlyOwner {
        enable = !enable;
    }

    function mint(uint256 _amount) public {
        _mint(_msgSender(),_amount);
    }


    function transferToken(address _recipient, uint256 _amount) public isEnable returns (bool){
        _transfer(_msgSender(),_recipient,_amount);
        return true;
    }
}