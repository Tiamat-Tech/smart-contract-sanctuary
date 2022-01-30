/**
 *Submitted for verification at Etherscan.io on 2022-01-30
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    //uint balance;
	mapping(address => uint) balance;
    uint _totalSupply;

    function deposit () public payable {
	balance[msg.sender] += msg.value;
    _totalSupply += msg.value;
    }

    function withdraw (uint amount) public {
        require(amount<=balance[msg.sender],"not enough money");
        payable(msg.sender).transfer(amount);
        balance[msg.sender] -= amount;
        _totalSupply -= amount;
    }

    function checkBalance() public view returns(uint) {
        //return balance;
	return balance[msg.sender];
    }

    function checkTotalSupply() public view returns (uint){
        return balance[msg.sender];
    }
}