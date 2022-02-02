//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";

contract Greeter {
    string private greeting;
    uint private phone;
    uint private age;

    constructor(string memory _greeting, uint   _phone , uint  _age) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
        phone = _phone;
        age = _age;
    }

    function greet() public view returns (string memory, uint  , uint ) {
        return (greeting, phone , age);
    }

    function setGreeting(string memory _greeting, uint  _phone , uint  _age) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
        phone = _phone;
        age = _age;
    }
}