//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Token{
    string public name = 'Mavrick';
    string public symbol = 'MVK';
    uint public totalSupply = 10000000;
    address public owner;

    mapping(address => uint) balances;

    constructor (){
        balances[msg.sender] = totalSupply;
        owner = msg.sender;
    }

    function transfer(address to,uint amount) external {
        require(balances[msg.sender] >= amount,'Not Enough Tokens');
        balances[to] += amount;
    }

    function balanceOf(address account) external view returns(uint){
        return balances[account];
    }
}