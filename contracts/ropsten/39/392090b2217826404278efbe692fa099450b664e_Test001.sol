/**
 *Submitted for verification at Etherscan.io on 2021-04-21
*/

pragma solidity ^0.4.18;

contract Test001 {
    
     
    string private message;
    
    function Test001() public  {
        message = "deneme123";    
    }
    
    function setMessage(string newMessage) payable public {
        message = newMessage;
    }
    
    function getMessage() public view returns (string) {
        return message;
    }
}