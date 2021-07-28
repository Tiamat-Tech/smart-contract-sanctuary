/**
 *Submitted for verification at Etherscan.io on 2021-07-28
*/

// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;

contract Token {
    string public name = "DUNY token";
    string public symbol = "DUNY";

    uint256 public totalSupply = 1000000000;
    address public owner;
    mapping(address => uint256) balances;

    constructor() {
        balances[msg.sender] = totalSupply;
        owner = msg.sender;
    }

    function transfer(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount, "Not enough tokens");

        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
}