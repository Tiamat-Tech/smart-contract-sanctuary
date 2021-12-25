// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TestTask is Ownable {

    address[] public donaters;

    function donate() public {
        address sender = msg.sender;
        donaters.push(sender);
    }

    function getDonaters() public view returns(address[] memory _donaters) {
        return donaters;
    }

    function withdraw() public onlyOwner {
    }
}