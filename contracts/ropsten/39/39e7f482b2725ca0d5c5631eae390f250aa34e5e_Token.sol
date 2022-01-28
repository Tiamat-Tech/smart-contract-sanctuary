/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

//SPDX-Licence-Identifier: MIT

pragma solidity ^0.8.6;

contract Token {
    string public name = "HighTrade";  // Name for coin
    string public symbol = "HTT";  // Symbol for Coin
    uint public decimals = 18;  // Can go to 18 decimals becasue Etherium runs on 18 decimal places
    uint public totalSupply = 20000000000000000000000000;  //20 million tokens with 18 extra zeros due to decimal number
    // Ethereum can't store decimals so all numbers need to be integers
    // uint stands for unsigned integer. Just means that value must be greater than zero

    mapping(address => uint256) public balanceOf;  // Assigns unique wallet ID to the number of tokens that ID has
    mapping(address => mapping(address => uint256)) public allowance;

    // Transfer event tells contract to log everytime the function is run. It logs from who , to who, and value transfered
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);


    // Constructor acts as a normal function, but constructor function is told to run as soon as contract is run
    // In string memory _name the function is told to access the name variable from the memory storage
    // We can pass these values into the constructor function instead of declaring them like on lines 5 - 8
    constructor(string memory _name, string memory _symbol, uint _decimals, uint _totalSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply; 
        balanceOf[msg.sender] = totalSupply;  // Tells function to assign total supply to the deployer of the contract
    }                                          // msg.sender is the person who deployed the contract


    // _to is the address we will send coins to and address before the variable states that _to is an address
    function transfer(address _to, uint256 _value) external returns (bool successful) {
        require(balanceOf[msg.sender] >= _value);
        balanceOf[msg.sender] = balanceOf[msg.sender] - (_value);  // Tells contract to subtract number of tokens from my account
        balanceOf[_to] = balanceOf[_to] + (_value);  // Tells contract to add number of tokens to receiver's account
        emit Transfer(msg.sender,_to,_value);  // Tells the Transfer event to run with the given values
        return true;
    }


    function _transfer(address _from, address _to, uint256 _value) internal {
        // Ensure sending is to valid address! 0x0 address cane be used to burn() 
        require(_to != address(0));
        balanceOf[_from] = balanceOf[_from] - (_value);
        balanceOf[_to] = balanceOf[_to] + (_value);
        emit Transfer(_from, _to, _value);
    }

    // Approve someone else to spend my tokens
    function approve(address _spender, uint256 _value) external returns (bool) {
        require(_spender != address(0));
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // Transfer from allows another account to distribute my tokens for me
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        require(_value <= balanceOf[_from]);
        require(_value <= allowance[_from][msg.sender]);
        allowance[_from][msg.sender] = allowance[_from][msg.sender] - (_value);
        _transfer(_from, _to, _value);
        return true;
    }

}