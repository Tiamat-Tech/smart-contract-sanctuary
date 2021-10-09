//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract Exodius {
    address public owner;
    mapping(address => uint256) public balanceOf;

    event Deposited(address depositor, uint256 value);
    event Claimed(address claimer, uint256 value);
    
    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {
        address sender = msg.sender;
        uint256 value = msg.value;

        balanceOf[sender] += value;

        emit Deposited(sender, value);
    }

    function claim() public payable {
        address payable sender = payable(msg.sender);
        
        sender.transfer(balanceOf[sender]);
    
        emit Claimed(sender, balanceOf[sender]);
    }
}