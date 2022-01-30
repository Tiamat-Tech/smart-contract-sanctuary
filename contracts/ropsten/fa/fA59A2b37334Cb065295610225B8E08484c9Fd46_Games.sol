/**
 *Submitted for verification at Etherscan.io on 2022-01-29
*/

// SPDX-License-Identifier: GPL-3.0
 
pragma solidity >=0.8.7;
 
interface _CasinoToken888{ // интерфейс токена 
    function transfer(address adr_to_send, uint number_of_tokens) external;
    function transfer_from(address _from, address _to, uint number_of_tokens) external;
    function my_balance() external view returns(uint);
    function balance_of_others(address adr) external view returns(uint);
 
}
 
contract Bank{ // контракт родитель, в котором назодятся функции свзанные с балансом
    _CasinoToken888 tok;
    address token_owner_address;
    address casino_owner;
    uint8 result = 2;
 
    constructor(address _owner){
        casino_owner = msg.sender;
        token_owner_address = _owner;
        tok = _CasinoToken888(token_owner_address);
    }

    modifier onlyOwner(){
        require(msg.sender == casino_owner, "Sorry, only owner of the casino can access this function");
        _;
    }

    function top_up_balance() public payable { // ф-ия пополнения баланса
        tok.transfer(msg.sender, msg.value);
    }
 
    function request_tokens(uint needed_balance) public onlyOwner{ // ф-ия запроса дополнительных токенов для баланса казино
        tok.transfer_from(token_owner_address, address(this), needed_balance);
    }

    function casino_balance() public view onlyOwner returns(uint256){ // ф-ия проверки баланса казино
        return(tok.my_balance());
    }

    function my_balance() public view returns(uint256){ // ф-ия проверки баланса пользователя
        return(tok.balance_of_others(msg.sender));
    }


}
 
 
contract Games is Bank{ // контракт-наследник от Bank. тут находятся функции игр и вся их логика
    constructor(address _owner) Bank(_owner){}
 
    modifier Pay (uint bet){
        require(bet >= 1 && bet <= tok.my_balance(), "Bet must bet at least 1 token");
        _;
    } 
 
    function rnd_for_roulette(address adr, uint8 number, string memory color, uint bet) view internal returns(uint8){ // ф-ия генерации случайного числа для 
 
        uint hashBlock = uint(blockhash(block.number - 1));
        uint hashAdr = uint(keccak256(abi.encode(adr)));
        uint hashNum = uint(keccak256(abi.encode(number)));
        uint hashCol = uint(keccak256(abi.encode(color)));
        uint hashBet = uint(keccak256(abi.encode(bet)));
 
        return(uint8(uint(keccak256(abi.encode(hashBlock % 1000 + hashAdr % 1000 + hashNum % 1000 + hashCol % 1000 + hashBet % 1000))) % 36) + 1);
 
    }

    function Roulette_bet_on_number(uint bet, uint8 number) public  Pay(bet){ // ф-ия, в которой реализована логика работы игры 'Ставка на чилсо'
        require(number >= 0 && number <= 36, "You must pick a number from 0 to 36");
        tok.transfer_from( msg.sender, address(this), bet);
 
        uint8 res = rnd_for_roulette(msg.sender, number, "TEMP", bet);
 
        if (res == number){
            tok.transfer_from(address(this), msg.sender, bet * 1000);
            result = 1;
        }
        else{
            result = 0;
        }
    }
 
    function Roulette_bet_on_color(uint bet, string memory color) public  Pay(bet){ // ф-ия, в которой реализована логика работы игры 'Рулетка'
        require((keccak256(abi.encodePacked(color)) == keccak256(abi.encodePacked("red"))) || (keccak256(abi.encodePacked(color)) == keccak256(abi.encodePacked("black"))) || (keccak256(abi.encodePacked(color)) == keccak256(abi.encodePacked("green"))), "Colors are 'black', 'red' and 'green'");


        tok.transfer_from( msg.sender, address(this), bet);
        uint16 res = rnd_for_roulette(msg.sender, 1, color, bet);
 
        if ((res == 0) && (keccak256(abi.encodePacked(color)) == keccak256(abi.encodePacked("green")))){
            tok.transfer_from(address(this), msg.sender, bet * 15);
            result = 1;
        }
        else if ((keccak256(abi.encodePacked(color)) == keccak256(abi.encodePacked("black"))) && (res >= 1) && (res <= 17)){
            tok.transfer_from(address(this), msg.sender, bet * 2);
            result = 1;
        }
        else if ((keccak256(abi.encodePacked(color)) == keccak256(abi.encodePacked("red"))) && (res >= 18) && (res <= 35)){
            tok.transfer_from(address(this), msg.sender, bet * 2);
            result = 1;
        }
        else{
            result = 0;
        }

    }

    function rnd_for_slot_machine(address adr, uint num) view internal returns(uint8){ // ф-ия генерации случайного числа для работы слот-машины
 
        uint hashBlock = uint(blockhash(block.number - 1));
        uint hashAdr = uint(keccak256(abi.encode(adr)));
        uint hashBet = uint(keccak256(abi.encode(num)));
 
        return(uint8(uint(keccak256(abi.encode(hashBlock % 1000 + hashAdr % 1000 + hashBet % 1000))) % 16));
 
    }
 
    function Slot_Machine_bet_and_try_your_luck(uint bet) public Pay(bet) { // ф-ия, в которой реализована логика работы игры 'Слот-машина'
        tok.transfer_from(msg.sender, address(this), bet);
        uint8 res1 = rnd_for_slot_machine(msg.sender, bet) + 1;
        uint8 res2 = rnd_for_slot_machine(msg.sender, res1) + 1;
        uint8 res3 = rnd_for_slot_machine(msg.sender, res2) + 1;
        if (res1 == res2 && res2 == res3 && res1 == res3){
            result = 1;
            tok.transfer_from(address(this), msg.sender, bet * 4);
        }
        else{
            result = 0;
        }
    }

    function check_result() public view returns(string memory){
        if (result == 1){
            return("Congrats! You've won");
        }
        else if (result == 2){
            return("You have not played yet");
        }
        else if (result == 0){
            return("Unfortunate! Try again");
        }
    }
}