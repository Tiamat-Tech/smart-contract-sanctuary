/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// Эта строка необходима для правильной работы с JSON
// SPDX-License-Identifier: GPL-3.0
// Устанавливаем версии компилятора
pragma solidity >=0.8.7;

// Делаем контракт - набор состояний и переходов
contract Token{
    address owner;
    string constant name = "DGameToken";
    string constant symbol = "DGT";
    uint8 constant decimals = 10;
    uint totalSupply = 0;
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;
    address gameAddress;

    event Transfer(address from, address to, uint value);
    event Approval(address from, address to, uint value);

    constructor(){
        owner = msg.sender;
    }

    function mint(address _to, uint _value)public{
        require(msg.sender == owner);
        totalSupply += _value;
        balances[_to] = _value;
    }

    function balanceOf()public view returns(uint){
        return balances[msg.sender];
    }

    function balanceOf(address _adr) public view returns(uint){
        return balances[_adr];
    }

    function transfer(address _to, uint _value) public{
        require(balances[msg.sender] >= _value, "You dont have that much money");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
    }

    function transferFrom(address _from, address _to, uint _value) public{
        require(balances[_from] >= _value, "You dont have that much money");
        require(allowed[_from][msg.sender] >= _value, "You cant spend so much");
        allowed[_from][msg.sender] -= _value;
        balances[_from] -= _value;
        balances[_to] += _value;
        emit Transfer(_from, _to, _value);
        emit Approval(_from, _to, allowed[_from][_to]);
    }

    function approve(address _spender, uint _value) public{
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    function allowance(address _from, address _to) public view returns(uint){
        return allowed[_from][_to];
    }

    function setGameAddress(address _game, address _owner) external{
        require (owner == _owner, "You are not an owner");
        gameAddress = _game;
    } 

    function transferFromGame(address _to, uint _value) external{
        require(msg.sender == gameAddress, "You are not from game");
        require(balances[owner] >= _value, "Owner dont have that much money");
        balances[owner] -= _value;
        balances[_to] += _value;
        emit Transfer(owner, _to, _value);
    }
}