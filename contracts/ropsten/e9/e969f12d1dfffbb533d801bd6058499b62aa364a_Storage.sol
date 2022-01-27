/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
// import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
contract Storage {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    address private _owner;
    constructor () public {
        address msgSender = msg.sender;
        _owner = msgSender;
    }
    uint256 number;
    string  public aaa;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;
    uint256 public totalSupply;
    function store(uint256 num) public{
        number = num;
    }

function retrieve() public view returns (address){
    return _owner;
}

function transfer(address to, uint amount) public returns (bool){
    return transferFrom(msg.sender, to, amount);
}

function transferFrom(address from, address to, uint value) public returns (bool) {
    require(balanceOf[from] >= value, "hahaha");

    if(from != msg.sender){
        require(allowance[from][msg.sender] >= value);
        allowance[from][msg.sender] -= value;
    }

    balanceOf[from] -= value;
    balanceOf[to] += value;

    emit Transfer(from,to,value);

    return true;

}

function setBalanceOf(address to, uint value) public{
    balanceOf[to] += value;
}
uint256 price = 500;
uint256 public SPIDER_MAN =0;
    function three_call(address addr) public {        
        addr.call(abi.encodeWithSignature("transferFrom(address,address,uint256)",msg.sender,address(0),price));                 // 1        
        // addr.delegatecall(bytes4(keccak256("test()")));       // 2        
        //addr.callcode(bytes4(keccak256("test()")));           // 3    
    } 

}