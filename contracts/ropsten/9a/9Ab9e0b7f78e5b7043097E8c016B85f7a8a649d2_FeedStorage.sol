//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FeedStorage is Initializable, Ownable{
    string private greeting;
    address[] private authorized_oracles;

    function findValue(address value) private returns(uint) {
        uint i = 0;
        while (authorized_oracles[i] != value) {
            i++;
        }
        return i;
    }

    function removeByValue(address value) private {
        uint i = findValue(value);
        removeByIndex(i);
    }

    function removeByIndex(uint i) private {
        while (i<authorized_oracles.length-1) {
            authorized_oracles[i] = authorized_oracles[i+1];
            i++;
        }
        delete authorized_oracles[authorized_oracles.length-1];
        //authorized_oracles.length--;
    }
    
    function removeOracles(address[] memory candidates ) public onlyOwner{
        for (uint i = 0; i < candidates.length; i += 1) {  //for loop example
            removeByValue(candidates[i]);
        }
    }

    function addOracles(address[] memory candidates ) public onlyOwner{
        for (uint i = 0; i < candidates.length; i += 1) {  //for loop example
            authorized_oracles.push(candidates[i]);
        }
    }
    
    function initialize(
       string memory _greeting
    ) public payable initializer {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
    }

    constructor(string memory _greeting) {
        initialize(_greeting);
    }

    function oracles() public view returns (address[] memory){
        return authorized_oracles;
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public onlyOwner{
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }
}