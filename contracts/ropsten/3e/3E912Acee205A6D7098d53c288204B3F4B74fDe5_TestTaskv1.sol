// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TestTaskv1 is Ownable {

    address[] private donaters;
    mapping(address => uint[]) private donations;

    function donate() payable public {
        donaters.push(msg.sender);
        donations[msg.sender].push(msg.value);
    }

    function getDonaters() public view returns(address[] memory _donaters) {
        return donaters;
    }

    function getDonaterDonataions(address _donater) public view returns(uint[] memory _donations) {
        return donations[_donater];
    }
}