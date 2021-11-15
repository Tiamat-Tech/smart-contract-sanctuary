//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Relay {
    // string private greeting;

    constructor() {
        // console.log("Deploying a Greeter with greeting:", _greeting);
        // greeting = _greeting;
    }

    // function greet() public view returns (string memory) {
    //     return greeting;
    // }

    // function setGreeting(string memory _greeting) public {
    //     console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
    //     greeting = _greeting;
    // }

    function send(address payable _recipient) public payable {
        console.log("Sending ether to '%s'", _recipient);
        _recipient.transfer(msg.value);
    }
}