/**
 *Submitted for verification at Etherscan.io on 2022-01-17
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;//เลือกเวอร์ชั่น
contract MyContract{

/*
โครงสร้างนิยามตัวเเปร
type access_modifier name;
*/

//private
string _name;
uint _balance;

constructor(string memory name,uint balance){
    require(balance > 0,"balance greater zero (money > 0)");
    _name = name;
    _balance = balance;
}

function getBalance() public view returns(uint balance){
    return _balance;
}

function deposit(uint amount) public{
    _balance+=amount;
}

}