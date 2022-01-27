/**
 *Submitted for verification at Etherscan.io on 2022-01-27
*/

pragma solidity ^0.8.4;

contract BellTower {
    uint public bellRung;

    event BellRung(uint rangForTheNthTime, address whoRangIt);

    function ringTheBell() public {
        bellRung ++;

        emit BellRung(bellRung, msg.sender);
    }
}