/**
 *Submitted for verification at Etherscan.io on 2021-12-27
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
    

contract NameContract {
    constructor(){

    }
    string Name;
    
    function getName() view public returns(string memory) {
        return Name;
    }
    
    function setName(string memory newName) public {
        Name = newName;
    }
}