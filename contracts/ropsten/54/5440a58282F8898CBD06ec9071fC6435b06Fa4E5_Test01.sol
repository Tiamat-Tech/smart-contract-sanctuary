//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract Test01 {
    address private owner;

    constructor() {
        owner = msg.sender;
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function donate() public payable {
    }

    function withdrawAll() public {
        require(msg.sender == owner, "You're not the owner!");
        payable(owner).transfer(address(this).balance);
    }
}