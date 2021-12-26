// SPDX-License-Identifier: MIX

pragma solidity >= 0.7.3;

contract HelloWorld { 
    event UpdatedMessages(string oldStr, string newStr);

    string public message;  // public means message is public

    constructor (string memory initMessage) { 
        message = initMessage;   // state variable = to Initmessage
    }

    function update(string memory newMessage) public {
        string memory oldMsg = message; 
        message = newMessage; 
        emit UpdatedMessages(oldMsg, newMessage);
    }
}