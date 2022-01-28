/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: GPL-3.0
 
pragma solidity >=0.8.7;
 
contract CasinoToken888{ // конртакт токена-валюты для казино
    string constant name = "CasinoToken888";
    string constant symbol = "888";
    uint8 constant decimals = 3;
    uint totalSupply = 0;
    mapping(address => uint256) balances; // словарь балансов
 
    address owner;
 
    modifier onlyOwner(){ 
        require(msg.sender == owner);
        _;
    }
 
    constructor(){
        owner = msg.sender;
        mint(address(this), 1000000000000000000000); // эмиссия огромного количества токенов
    }
 
    function mint(address adr, uint number_of_tokens) public onlyOwner { // ф-ия проведения эмиссии
        totalSupply += number_of_tokens;
        balances[adr] += number_of_tokens;
    }
 
    function transfer(address adr_to_send, uint number_of_tokens) external { // ф-ия переаода токенов с баланса вызвавшего ф-ию на любой адрес
        require((balances[msg.sender] >= number_of_tokens) && (adr_to_send == owner));
        balances[msg.sender] -= number_of_tokens;
        balances[adr_to_send] += number_of_tokens;
    }
 
    function transfer_from(address _from, address _to, uint number_of_tokens) external onlyOwner {  // ф-ия перевода со стороннего аккаунта на другой
        require(balances[_from] >= number_of_tokens);
        balances[_from] -= number_of_tokens;
        balances[_to] += number_of_tokens;
    }
 
    function balance_of_others(address adr_from, address adr) public view  onlyOwner returns(uint){ // ф-ия просмотра баланса аккаунта по адресу
        require (adr_from == owner, "This function is available only for thw owner");
        return(balances[adr]);
    }
 
    function balance_of(address adr) public view returns(uint){ // ф-ия просмотра баланса вызвавшего ф-ию
        return(balances[adr]);
    }
 
 
 
}