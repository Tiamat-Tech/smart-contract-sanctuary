//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract Greeter is Ownable {
    string private greeting;
    address private _owner;

    // modifier onlyOwner() {
    //     require(
    //         msg.sender == _owner,
    //         "Ownable: caller is not the owner"
    //     );
    //     _;
    // }

    constructor() {
        _owner = 0x6D53182cd12d5Ab1389550D14CF99a07D9cefeF3;
    }

    // constructor(string memory _greeting) {
    //     console.log("Deploying a Greeter with greeting:", _greeting);
    //     greeting = _greeting;
    //     greeting2 = string(abi.encodePacked(_greeting, "2"));
    // }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public onlyOwner {
        console.log("Message sender is %s", msg.sender);
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }
}