//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
    string private helloString;

    constructor(string memory _hello) {
        console.log("Deploying a Greeter with greeting:", _hello);
        helloString = _hello;
    }

    function sayHello() public view returns (string memory) {
        return helloString;
    }

    function setGreeting(string memory _hello) public {
        console.log("Changing greeting from '%s' to '%s'", helloString, _hello);
        helloString = _hello;
    }
}