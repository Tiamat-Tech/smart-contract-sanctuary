/**
 *Submitted for verification at Etherscan.io on 2021-09-06
*/

pragma solidity ^0.5.1;

contract timeLock {

    uint256 lockTime = 1 days;

    struct locked{
        uint256 expire;
        uint256 amount;
    }

    mapping(address => locked) users;

    function lockEther() public payable {
        require(msg.value>0);
        locked storage userInfo = users[msg.sender];
        userInfo.expire = block.timestamp + lockTime;
        userInfo.amount = msg.value;
    }

    function withdraw() public {
        require(block.timestamp>=users[msg.sender].expire);
        locked storage userInfo = users[msg.sender];
        uint256 value = userInfo.amount;
        userInfo.expire = 0;
        userInfo.amount = 0;
        msg.sender.transfer(value);
    }



}