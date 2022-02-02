/**
 *Submitted for verification at Etherscan.io on 2022-02-01
*/

pragma solidity ^0.8.4;

contract BellTower{
    uint public bellRung;

    event BellRung(uint rangFortheNthTime, address whoRangit); 

    function ringTheBell() public {
        bellRung++;
        emit BellRung(bellRung, msg.sender);
    }
}