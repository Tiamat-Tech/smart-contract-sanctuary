// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "AggregatorV3Interface.sol";
import "SafeMathChainlink.sol";

contract FundMe{
    struct Pledge {
        address pledger;
        uint amount;
        uint timestamp;
    }

    address public owner;
    mapping(address => uint) public total_pledged;
    Pledge[] public pledges;
    uint256 minimum_pledge;

    constructor() public {
        owner = msg.sender;
        minimum_pledge = 100;
    }

    function pledge() public payable {
        pledges.push(
            Pledge({
                pledger: msg.sender,
                amount: msg.value,
                timestamp: block.timestamp
            })
        );
        total_pledged[msg.sender] += msg.value;
    }

    modifier onlyOwner {require(msg.sender == owner); _;}
    function withdraw(uint amount) onlyOwner public payable returns (uint) {
        require (msg.sender == owner);
        require (amount <= address(this).balance);
        payable(msg.sender).transfer(amount);
        return address(this).balance;
    }

    function get_total_pledged_by(address _addr) public view returns (uint) {
        return total_pledged[_addr];
    }

    function get_pledge(uint index) public view returns (address, uint, uint) {
        Pledge memory p = pledges[index];
        return (p.pledger, p.amount, p.timestamp);
    }

}