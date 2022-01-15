// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract TimacumToken is ERC20{


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
    constructor(uint initialSupply) ERC20("TimacumToken","TMC"){
       initialSupply=10000000*10**8;
       _totalSupply=initialSupply;
        owner=msg.sender;
       _mint(owner, initialSupply);
        addr1=0xdba24d6953Dc13864138d9A652B3926082fa46AA;
        addr2=0xB15347EBC39CA60D839E8a77d6569B6eeD39F1a8;
        addr3=0xaF4357C70456b78b043FcAB62E01F9e7650dC895;
        
     perecent=1000000*(10**8);
     newTotalSupply=initialSupply-perecent;
     kolicnik=newTotalSupply/3;
        
        transfer(addr2, kolicnik);
     emit Transfer(owner,addr2, kolicnik);
         transfer(addr3, kolicnik);
     emit Transfer(owner, addr3, kolicnik);
        
   
}


function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

function decimals() public view virtual override returns (uint8) {
        return 8;
    }

}