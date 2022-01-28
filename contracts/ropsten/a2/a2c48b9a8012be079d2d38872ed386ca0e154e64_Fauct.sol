/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

pragma solidity ^0.4.17;

contract Fauct {
    function withdraw(uint amount) public {
        require(amount <= 1000000000000000000);
        msg.sender.transfer(amount);
    }
    function () public payable{}
}