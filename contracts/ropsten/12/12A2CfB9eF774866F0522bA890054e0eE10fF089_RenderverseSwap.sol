//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Token.sol";

contract RenderverseSwap is AccessControl {

    address private TokenAddress;
    address private owner;
    uint256 public presaleEther; 
    uint256 public postsaleEther;

    constructor(address _tokenAddress){
        TokenAddress = _tokenAddress;
        owner = _msgSender();
    }

    function preSale(address payable sender) public  payable {
        
        payable(_msgSender()).transfer(presaleEther);
        Token(TokenAddress).transferToken(sender,msg.sender,1);
    }

    function publicSale() public{
        
    }
}