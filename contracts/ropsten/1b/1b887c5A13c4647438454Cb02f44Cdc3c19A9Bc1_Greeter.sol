//SPDX-License-Identifier: Unlicense
pragma solidity 0.7.5;

import "hardhat/console.sol";

contract Greeter {
    string public greeting;
    address public owner;

    modifier isOwner {
        require(msg.sender == owner, "Only the owner can do this");
        _;
    }

    constructor(string memory _greeting) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
        owner = msg.sender;
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public isOwner {
        //console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }
}