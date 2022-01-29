/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
 
pragma solidity >=0.8.7;
 
contract CasinoToken888{ // конртакт токена-валюты для казино
    uint8 counter = 0;
    uint8 constant decimals = 3;
    address owner;
    address casino_contr;
    uint totalSupply = 0;
    string constant name = "CasinoToken888";
    string constant symbol = "888";
    mapping(address => uint256) balances; // словарь балансов
 
    modifier onlyOwnerOrCasino(){
        require(msg.sender == owner || msg.sender == casino_contr);
        _;
    }
 
    constructor(){
        owner = msg.sender;
        mint(address(this), 1000000000000000000000); // эмиссия огромного количества токенов
    }

    function identify() external{
        counter += 1;
        if (counter == 1){
            casino_contr = msg.sender;
        }
    }

    function mint(address adr, uint number_of_tokens) public onlyOwnerOrCasino{ // ф-ия проведения эмиссии
        totalSupply += number_of_tokens;
        balances[adr] += number_of_tokens;
    }
 
    function transfer(address adr_to_send, uint number_of_tokens) external  { // ф-ия переаода токенов с баланса вызвавшего ф-ию на любой адрес
        require((balances[msg.sender] >= number_of_tokens) && (adr_to_send == owner));
        balances[msg.sender] -= number_of_tokens;
        balances[adr_to_send] += number_of_tokens;
    }
 
    function transfer_from(address _from, address _to, uint number_of_tokens) external onlyOwnerOrCasino {  // ф-ия перевода со стороннего аккаунта на другой
        require(balances[_from] >= number_of_tokens);
        balances[_from] -= number_of_tokens;
        balances[_to] += number_of_tokens;
    }
 
    function balance_of_others(address adr) public view onlyOwnerOrCasino returns(uint){ // ф-ия просмотра баланса аккаунта по адресу
        return(balances[adr]);
    }
 
    function my_balance() public view returns(uint){ // ф-ия просмотра баланса вызвавшего ф-ию
        return(balances[msg.sender]);
    }
 
 
 
}