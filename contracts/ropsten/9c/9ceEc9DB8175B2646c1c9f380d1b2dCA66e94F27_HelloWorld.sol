/**
 *Submitted for verification at Etherscan.io on 2021-12-07
*/

pragma solidity 0.6.5;

contract HelloWorld{
    uint balance;
    function update(uint a, uint b) public view returns (uint){
        uint c;
        c = a + b + balance;
        return c;
    }
}