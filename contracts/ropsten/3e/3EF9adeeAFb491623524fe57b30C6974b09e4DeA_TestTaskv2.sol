// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TestTaskv2 is Ownable {

    address[] private donaters;
    mapping(address => uint[]) private donations;

    function donate() public payable {
        donaters.push(msg.sender);
        donations[msg.sender].push(msg.value);
    }

    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    function getDonaters() public view returns(address[] memory) {
        return donaters;
    }

    function getDonaterDonataions(address _donater) public view returns(uint[] memory) {
        return donations[_donater];
    }

    function withdraw(address payable toAddress) public payable onlyOwner {
        toAddress.transfer(address(this).balance);
    }
}