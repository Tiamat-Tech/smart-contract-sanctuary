/**
 *Submitted for verification at Etherscan.io on 2021-05-25
*/

pragma solidity ^0.6.6;

contract CoolNumberContract {
    uint public coolNumber = 10;
    
    function setCoolNumber(uint _coolNumber) public {
        coolNumber = _coolNumber;
    }
}