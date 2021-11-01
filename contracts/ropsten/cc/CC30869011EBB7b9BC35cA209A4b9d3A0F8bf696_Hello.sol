//SPDX-License-Identifier: Unlicense
pragma solidity =0.6.12;

import "hardhat/console.sol";

contract Hello {
    string private greeting;

    constructor(string memory _greeting) public {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
    }

    function greetTwo() public view returns (string memory) {
        return greeting;
    }

    function setGreetingTwo(string memory _greeting) public {
        console.log(
            "Two Changing greeting from '%s' to '%s'",
            greeting,
            _greeting
        );
        greeting = _greeting;
    }
}