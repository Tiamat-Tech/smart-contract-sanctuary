//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;
import "./Lab1.sol";

contract ILab1 {
  Lab1 lab;
  
  event CreateLab(address indexed from);
  function createLab() public returns (address){
    lab = new Lab1();
    emit CreateLab(msg.sender);
    return address(lab);
  }
  
  function isCompleted() public view returns (bool){
    return lab.isCompleted();
  }
}