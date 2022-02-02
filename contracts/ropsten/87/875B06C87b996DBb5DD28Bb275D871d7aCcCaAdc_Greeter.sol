//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
    string private greeting;
    string private message;

    constructor(string memory _greeting, string memory _message) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
        message = _message;
    }

    function greet() public view returns (string memory, string memory) {
        return (greeting , message);
    }

    function setGreeting(string memory _greeting, string memory _message) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
        message = _message;
    }
}