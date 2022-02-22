// SPDX-License-Identifier: Unlisenced

pragma solidity ^0.8.0;

interface Target {
    function devMint(uint256) external payable;
}

contract Interaction 
{
    function getCount() external payable{
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
        Target(0x449DD76bc5D8306d1784430Bad2c16e6B7f15188).devMint(5);
    }
}