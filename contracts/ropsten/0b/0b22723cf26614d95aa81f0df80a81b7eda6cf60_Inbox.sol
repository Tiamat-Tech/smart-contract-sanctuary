/**
 *Submitted for verification at Etherscan.io on 2021-02-04
*/

pragma solidity ^0.4.17;

contract Inbox {
    string public message;

    function Inbox (string initialMessage) public {
        message = initialMessage;
    }

    function setMessage (string newMessage) public {
        message = newMessage;
    }
}