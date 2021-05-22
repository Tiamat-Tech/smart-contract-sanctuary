/**
 *Submitted for verification at Etherscan.io on 2021-05-21
*/

pragma solidity 0.8.2;

contract BToken {
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowance;
    uint public totalSupply = 100000 * 10 ** 18;
    string public name = "My Token";
    string public symbol = "LFG";
    uint public decimals = 18;
    
    event Transfer(address indexed from, address indexed to, uint value);
    event approval(address indexed owner, address indexed spender, uint value);
    // here we declare an event that will make use of the following arguments//
    
    constructor() {
        balances[msg.sender] = totalSupply; // with this we send all the Token to the address of the sender at deployment//
        
    }
    
    function balanceOf(address owner) public view returns(uint) {
        return balances[owner]; // in this case we create a function that can be called from outside to view the balance of address//
    }
    
    function transfer(address to, uint value) public returns(bool) {
        require(balanceOf(msg.sender) >= value, 'balance too low');
         balances[to] += value;
         balances[msg.sender] -= value;
         emit Transfer(msg.sender, to, value);
         return true;
    }
    
    // function to create delegated transfer//
    
    function transferFrom(address from, address to, uint value) public returns(bool) {
        require(balanceOf(msg.sender) >= value, 'bakance too low');
        require(allowance[from][msg.sender] >= value, 'bakance too low' );
        balances[to] += value;
        balances[from] -= value;
        emit Transfer(from, to, value);
        return true;
    }
    
    function approve(address spender, uint value) public returns(bool) {
        allowance [msg.sender][spender] = value; 
        emit approval(msg.sender, spender, value);
        return true;
    }
}