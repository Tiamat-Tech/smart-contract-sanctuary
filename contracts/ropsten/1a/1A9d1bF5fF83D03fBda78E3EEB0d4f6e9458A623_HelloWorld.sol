// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract HelloWorld is Ownable {

    string public greeting;

    constructor() {
        greeting = "Hello, world";
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _newGreeting) public onlyOwner {
        greeting = _newGreeting;
    }
}