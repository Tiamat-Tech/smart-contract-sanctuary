// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CarToken is Ownable{
    string public name = "CAR Token";
    string public symbol = "CAR";
    address public _owner;

    uint public totalSupply = 1000000000;
    mapping(address => uint) balances;

    constructor(){
        _owner = msg.sender;
        balances[msg.sender] = totalSupply;
    }

    function transfer(address to, uint amount) external {
        require(balances[msg.sender] >= amount, 'Not enough tokens');
        // Deduct from sender, Add to receiver 
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }

    function withdraw() external payable onlyOwner {
        payable(_owner).transfer(address(this).balance);
    }   

}