// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract Tokenche is ERC20{


uint _totalSupply;
uint public perecent;
uint newTotalSupply;
uint kolicnik;
address public owner;
address addr1;
address addr2;
address addr3;
     mapping(address => uint256) public _balances;

    mapping(address => mapping(address => uint256)) private _allowances;
    constructor(uint initialSupply) ERC20("Tokenche","TO"){
       initialSupply=10000000*10**8;
       _totalSupply=100000000*10**8;
        owner=msg.sender;
       _mint(owner, initialSupply);
       
        
     
    
}


function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

function decimals() public view virtual override returns (uint8) {
        return 8;
    }

}