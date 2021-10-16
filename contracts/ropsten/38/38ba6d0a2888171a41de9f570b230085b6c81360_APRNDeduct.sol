/**
 *Submitted for verification at Etherscan.io on 2021-10-16
*/

/**
 *Submitted for verification at Etherscan.io on 2021-07-17
*/
//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.4;


contract APRNDeduct {
    mapping (address => uint) balances;
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    constructor()  {
        balances[tx.origin] = 10000;
    }
    function sendCoin(address receiver, uint amount) public returns(bool success) {
        if (balances[msg.sender] < amount) return false;

        balances[msg.sender] -= amount;
        balances[receiver] += amount;
        emit Transfer(msg.sender, receiver, amount);
        return true;    }

    function getBalance(address addr) public view returns(uint) {
        return balances[addr];
    }
}