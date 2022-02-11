//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract MessageWall {

    struct Message {
        string sender;
        string message;
    }
    
    mapping(uint => Message) private messages;
    uint private messageCount;

    constructor() {
        console.log("Deploying a MessageWall contract");
        messageCount = 0;
    }

    function getMessageCount() public view returns (uint) {
        return messageCount;
    }

    function getMessage(uint index) public view returns (Message memory) { 
        return messages[index];
    }

    function renderWall() public view returns (string memory) {
        string memory phrase = "";
        string memory separator;
        uint i;
        
        for(i = 0; i < messageCount; i++){
            separator = i == 0 ? "" : " ";
            console.log(i);
            phrase =  string(abi.encodePacked(phrase, separator, messages[i].message));
        }
        return phrase;
    }

    function addMessage(string memory _message, string memory _sender) public {
        messages[messageCount] = Message({sender:_sender , message:_message });
        messageCount++;
    }
}