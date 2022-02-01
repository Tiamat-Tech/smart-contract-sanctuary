//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
    string private mygreeting;
    mapping (address => uint) public balances;

    constructor(string memory _greeting) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        mygreeting = _greeting;
    }

    function greet() public view returns (string memory) {
        console.log("ZC test");
        return mygreeting;
    }

    function setMyGreeting(string memory _greeting) public {
        console.log("Changing greeting from '%s' to '%s'", mygreeting, _greeting);
        mygreeting = _greeting;
    }

    function setBalance(uint amount) public {
        balances[msg.sender] = amount;
    }

    function getBalance() public returns (uint) {
        return balances[msg.sender];
    }
}