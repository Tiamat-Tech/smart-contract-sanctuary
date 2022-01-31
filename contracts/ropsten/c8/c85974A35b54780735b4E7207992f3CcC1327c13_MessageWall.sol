//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract MessageWall {
    string[] private messages;

    constructor(string[] memory _messages) {
        console.log("Deploying a MessageWall with content:", _messages.length);
        messages = _messages;
    }

    function renderWall() public view returns (string memory) {
        string memory phrase = "";
        string memory separator;
        uint i;
        
        for(i = 0; i < messages.length; i++){
            separator = i == 0 ? "" : " ";
            console.log(i);
            phrase =  string(abi.encodePacked(phrase, separator, messages[i]));
        }
        return phrase;
    }

    function addMessage(string memory _message) public {
        console.log("Adding greeting '%s'", _message);
        messages.push(_message);
    }
}