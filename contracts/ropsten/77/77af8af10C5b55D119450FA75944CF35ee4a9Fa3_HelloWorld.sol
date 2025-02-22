//SPDX-License-Identifier: Unlicense
pragma solidity >= 0.8.0;

import "hardhat/console.sol";

contract HelloWorld {

    event UpdatedMessages(string oldStr, string newStr);

    string public message;

    constructor(string memory initMessage) {
        message = initMessage;
    }

    function update(string memory newMessage) public {
        string memory oldMsg = message;
        message = newMessage;
        emit UpdatedMessages(oldMsg, newMessage);
    }
}