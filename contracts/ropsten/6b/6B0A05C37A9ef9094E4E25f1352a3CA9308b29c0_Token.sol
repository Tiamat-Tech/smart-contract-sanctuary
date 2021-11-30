//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Token is ERC20 , AccessControl{


     address public owner; 
     bool private enable;
     uint256 private limitSupply;

    constructor(string memory _tokenName , string memory _tokenSymbol,uint256 _totalSupply)ERC20(_tokenName,_tokenSymbol){
        owner = msg.sender;
        limitSupply = _totalSupply;
        _setupRole("MINTING_ROLE", msg.sender);
    }

    modifier isMinter(address _address){
        require(hasRole("MINTING_ROLE",_address)==true,"MINTING ROLE NOT DEFINED FOR THE USER");
        _;
    }

    modifier onlyOwner{
        require(_msgSender() == owner,"THIS FUNCTION ONLY WORKS FOR OWNER");
        _;    
    } 

    modifier isEnable{
        require(enable==false,"This function is not active currently");
        _;
    }


    function getLimitSupply() public view returns(uint256){
        return limitSupply;
    }

    function addMintingRole() public {
        grantRole("MINTING_ROLE", msg.sender);
    }

    function changeBool() public onlyOwner {
        enable = !enable;
    }

    function mint(uint256 _amount) public  isMinter(_msgSender()) {
        require(totalSupply() <= limitSupply ,"Minting limit excedded");
        _mint(_msgSender(),_amount);
    }

    function transferToken(address _recipient, uint256 _amount) public isEnable returns (bool){
        _transfer(_msgSender(),_recipient,_amount);
        return true;
    }
}