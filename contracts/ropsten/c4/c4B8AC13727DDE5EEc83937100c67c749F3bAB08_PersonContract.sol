//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract PersonContract {
    struct Person {
        string firstName;
        string lastName;
    }

    address Owner;

    mapping(address => Person) People;

    address[] PeopleArray;

    constructor(){
        Owner = msg.sender;
    }

    function setPerson(address  _address, string memory _firstName, string memory _lastName) public {
        console.log("Setting person");
               
        People[_address].firstName = _firstName;
        People[_address].lastName = _lastName;

        PeopleArray.push(_address);
    }

    function getPeopleLedger() view public returns(address[] memory){
        return PeopleArray;
    }

    function getPerson(address _address) view public returns(string memory, string memory){
        return (People[_address].firstName,People[_address].lastName);
    }

    function countPeople() view public returns(uint){
        return PeopleArray.length;
    }  
}