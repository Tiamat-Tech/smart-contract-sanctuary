//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
    string private greeting; 
    bool public flag ; 

    constructor(string memory _greeting) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting; 
        flag = false ; 
    } 

    function setFlag() external  {
        flag = !flag ; 
    }


    function greet() public view returns (string memory) {
        require(flag ,"FLAG_NOT_SET") ; 
        return greeting;
    }

    function setGreeting(string memory _greeting) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }
}