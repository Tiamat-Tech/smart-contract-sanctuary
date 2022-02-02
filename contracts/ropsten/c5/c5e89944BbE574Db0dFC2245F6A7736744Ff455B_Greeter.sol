//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
    string private greeting;
    string private name;
    uint private age;

    constructor(string memory _greeting, string memory _name , uint  _age) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
        name = _name;
        age = _age;
    }

    function greet() public view returns (string memory, string memory , uint ) {
        return (greeting, name , age);
    }

    function setGreeting(string memory _greeting, string memory _name , uint  _age) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
        name = _name;
        age = _age;
    }
}