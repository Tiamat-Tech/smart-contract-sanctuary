/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract Messagebox {
    string[] internal message;
    event NewMessage(address indexed author, string message);


    constructor() {
        message.push("Hello world!");
    }

    function setMessage(string memory newMessage) public payable{
        require(msg.value == 0.001 ether, "se debe pagar 0.001 ethers");
        message.push(newMessage);
        emit NewMessage(msg.sender,newMessage );
    }

    function getMessage() public view returns(string[] memory ) {
        return message;
    }

}