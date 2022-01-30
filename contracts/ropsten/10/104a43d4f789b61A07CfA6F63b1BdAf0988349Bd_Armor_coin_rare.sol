/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

contract Armor_coin_rare{
    string public name = "ArmorRareCoin";
    string public symbol = "ARC";
    uint8 public decimals = 6;
    uint16 public totalSupply = 0;
    address public owner;
    bool constant rare = true;

    mapping(address => uint) balances;
  
    constructor(){
        owner = msg.sender;
    }
    
    modifier onlyOwner(){
    require(msg.sender == owner);
    _;
    }

    function mint_rare(address _address, uint16 _amount) public onlyOwner{
        totalSupply += _amount;
        balances[_address] += _amount;
    }

    function balanceOf_rare(address _address)public view returns(uint){
        return balances[_address];

    }

    function transfer(address _adres, uint8 _value)public{
        require(balances[owner] > _value);
        balances[_adres] += _value;
        balances[owner] -= _value;
    }
}