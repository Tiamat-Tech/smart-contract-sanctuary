/**
 *Submitted for verification at Etherscan.io on 2022-01-28
*/

pragma solidity ^0.8.11;

contract Counter {
    uint public count;

    function add() external {
        count += 1;
    }
}