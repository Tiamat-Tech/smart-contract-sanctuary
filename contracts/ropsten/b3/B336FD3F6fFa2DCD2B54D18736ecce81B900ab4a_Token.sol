//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Token is ERC20 , AccessControl{

     using SafeMath for uint256;

     address public owner; 
     bool private enable;
     uint256 private limitSupply;
     uint256 _decimals = 18;

    constructor(string memory _tokenName , string memory _tokenSymbol)ERC20(_tokenName,_tokenSymbol){
        owner = msg.sender;
        mint(_msgSender(), uint256(1).mul(10**22));
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

    function mint(address _receipient,uint256 _amount) private {
        _mint(_receipient,_amount);
    }

    function transferToken(address sender,address _recipient, uint256 _amount) public isEnable returns (bool){
        _transfer(sender,_recipient,_amount);
        return true;
    }
}