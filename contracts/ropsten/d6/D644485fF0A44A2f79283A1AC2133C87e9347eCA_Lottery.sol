pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";

// import "@openzeppelin/contracts/access/Ownable.sol";
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract Lottery {
    address payable[] public players;
    address public manager;

    constructor() {
        manager = msg.sender;
    }

    receive() external payable {
        players.push(payable(msg.sender));
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}