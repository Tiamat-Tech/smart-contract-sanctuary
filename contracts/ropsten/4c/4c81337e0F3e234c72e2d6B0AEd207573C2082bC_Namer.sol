//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract Namer {
    struct Pair {
        string name;
        address addr;
    } 

    address public manager;
    mapping(string => address) private nameMaps;
    Pair[] public allPairs;

    constructor() {
        manager = msg.sender;
    }

    function setName(string memory name) public {
        bool isNameUnique = false;
        if (nameMaps[name] == address(0)) {       // ONLY unique names
            nameMaps[name] = msg.sender;   // Add msg.sender(address) to nameMap
            isNameUnique = true;

            Pair storage newPair = allPairs.push();
            newPair.name = name;
            newPair.addr = msg.sender;
        }

        require(isNameUnique, "Another address already exists with the same name!");
    }
    function readName(string memory name) public view returns (address) {
        if (nameMaps[name] != address(0)) {
            return nameMaps[name];
        }
        else {
            return address(0);
        }
    }

    function getAllPairs() public view returns (Pair[] memory) {
        return allPairs;
    }
}