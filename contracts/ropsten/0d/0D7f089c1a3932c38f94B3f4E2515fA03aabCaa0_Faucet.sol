// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";


contract Faucet is Ownable {
    
using SafeMath for uint256;    

IERC20 private DAI;  

uint256 public tokensPerEther =  100;


event Received(address,uint);


constructor(address _DAI) {
    
    DAI = IERC20(_DAI);
}


receive() external payable {
    
   emit Received(msg.sender,msg.value);

}


// Balance


function balanceOf(address user) public view returns(uint256) {
    
    return DAI.balanceOf(user);
}


//  Request Dai


function RequestDAI(address recipient,uint256 amount) external payable {
    
    uint256 eth = amount.mul(tokensPerEther);
    
    require (msg.value >= eth," Insufficient amount") ;
    
    uint256 value = msg.value.sub(eth);
    
    require(DAI.balanceOf(address(this))>= amount , "Insufficient funds");
    
    IERC20(DAI).transfer(recipient,amount);
    
    payable(msg.sender).transfer(value);
    
}  


// 


function getbalance() public view returns (uint256) {
    
    return DAI.balanceOf(address(this));
}


// transfer


function transfer( address recipient, uint256 amount) public  {
    
    require(recipient != address(0));
    
    require(DAI.balanceOf(msg.sender) >= amount , "You dont have enough balance in your wallet");
    
    // IERC20(DAI).approve(address(this),amount);
    
    IERC20(DAI).transferFrom(msg.sender,recipient,amount);
    
}


// approve


 function approve(uint256 amount) public {
     
    // require(DAI.balanceOf(msg.sender) >= amount , "You dont have enough balance in your wallet");

    IERC20(DAI).approve(address(this),amount);
}


// withdraw
  
  
function withdraw() public onlyOwner {
    
    uint balance = address(this).balance;
    
    payable(msg.sender).transfer(balance);

}    
    
    
    
    
    
    
    
}