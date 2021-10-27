//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Greeter {
    string private greeting;

    constructor(string memory _greeting) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }

    function add(uint256 x, uint256 y) public pure returns (uint256) {
        return x + y;
    }

    function sub(uint256 x, uint256 y) public pure returns (int256) {
        return int256(x) - int256(y);
    }

    function testSumArray() public pure returns (bool) {
        uint256[] memory arr = new uint256[](3);
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;
        uint256 sum = 0;
        for (uint256 index = 0; index < arr.length; index++) {
            sum += arr[index];
        }


        if(sum == 6) {
            return true;
        }

        return false;
    }
}