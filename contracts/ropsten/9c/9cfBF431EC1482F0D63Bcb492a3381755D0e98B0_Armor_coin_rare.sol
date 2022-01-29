/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

contract Armor_coin_rare{
    string public name = "ArmorRareCoin";
    string public symbol = "ARC";
    uint8 public decimals = 8;
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

    function mint_rare(address _address, uint8 _amount) public onlyOwner{
        totalSupply += _amount;
        balances[_address] += _amount;
    }

    function balanceOf_rare(address _address)public view returns(uint){
        return balances[_address];

    }

    function transfer_rare(address _to, uint8 _from)public{
        require(balances[msg.sender] > _from);
        balances[msg.sender] -= _from;
        balances[_to] += _from;
    }
}