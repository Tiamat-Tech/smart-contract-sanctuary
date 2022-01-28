/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

contract VietnamCoin{
    string public name = "VietCoin";
    string public symbol = "VtC";
    uint8 public decimals = 5;
    uint8 public totalSupply = 0;
    address public owner;
  
    constructor(){
        owner = msg.sender;
    }

    event Transfer(address _from, address _to, uint8 _amount);
    event Approval(address _from, address _to, uint8 _amount);

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;


    modifier onlyOwner(){
    require(msg.sender == owner);
    _;
    }

    function mint(address _address, uint8 _amount) public onlyOwner{
        totalSupply += _amount;
        balances[_address] += _amount;
    }

    function balanceOf(address _address)public view returns(uint){
        return balances[_address];

    }

    function transfer (address _to, uint8 _amount)public{
        require(balances[msg.sender] > _amount);
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
        emit Transfer(msg.sender, _to, _amount);
    }

    function transferFrom(address _to, address _from, uint8 _value)public{
        require(balances[_from] > _value);
        require(allowed[_from][msg.sender] >= _value);
        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][msg.sender] -=_value;
        emit Transfer(_from, _to, _value);
        emit Approval(_from, _to, _value);
    }

    function approve(address _spender, uint8 _value)public{
            allowed[msg.sender][_spender] = _value;
            emit Approval(msg.sender, _spender, _value);
    }

    function allowance(address _from, address _spender)public view returns (uint){
        return allowed[_from][_spender];
    }
}