/**
 *Submitted for verification at Etherscan.io on 2021-12-07
*/

// SPDX-License-Identifier: MIT


pragma solidity 0.8.0;

contract test{
    uint state = 0;
    function testfunc(uint _add) public payable{
        require(msg.value == 0.001 ether, "not the right amount!");
        state += _add;
    }

}