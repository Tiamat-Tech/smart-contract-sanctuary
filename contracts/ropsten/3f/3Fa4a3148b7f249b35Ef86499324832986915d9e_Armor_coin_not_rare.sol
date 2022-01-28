/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

contract Armor_coin_not_rare{
    string public name = "ArmorSimpleCoin";
    string public symbol = "ASC";
    uint8 public decimals = 20;
    uint8 public totalSupply = 0;
    address public owner;
    bool constant rare = false;

    mapping(address => uint) balances;
  
    constructor(){
        owner = msg.sender;
    }

    modifier onlyOwner(){
    require(msg.sender == owner);
    _;
    }

    function mint_rare(address _address, uint8 _amount) public onlyOwner{
        totalSupply += _amount;
        balances[_address] += _amount;
    }

    function balanceOf_rare(address _address)public view returns(uint){
        return balances[_address];

    }

    function transfer_rare(uint8 _value)public{
        require(balances[msg.sender] > _value);
        balances[msg.sender] += _value;
        balances[owner] -= _value;
    }
}