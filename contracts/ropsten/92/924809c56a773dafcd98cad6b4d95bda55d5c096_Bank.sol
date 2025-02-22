/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    mapping(address => uint) _balances;

    // owner phu fark & phu thorn
    // envent kheu kan jub thouk hed kan
    // emit pen kan jaeng hed kan va phai pen khon hed thou la kam

    event Deposit(address indexed owner, uint amount);
    event Withdraw(address indexed owner, uint amount);

    // Function Deposit
    function deposit() public payable {
        require(msg.value > 0, "deposit money is zero");

        _balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // Function Withdraw
    function withdraw(uint amount) public {
        require(amount > 0 && amount <= _balances[msg.sender], "not enough money");
        
        payable(msg.sender).transfer(amount);
        _balances[msg.sender] -= amount;
        emit Withdraw(msg.sender, amount);
    }

    // Function Check Balances
    function balances() public view returns(uint){
        return _balances[msg.sender];
    }

    // Function Balances Of
    function balancesOf(address owner) public view returns(uint){
        return _balances[owner];
    }

}