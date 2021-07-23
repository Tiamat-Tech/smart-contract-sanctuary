//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.6;
import "./Lab1.sol";

contract ILab1 {
  Lab1 lab;
  address labAddr;

  event CreateLab(address indexed from);
  
  function createLab() public {
    lab = new Lab1();
    labAddr = address(lab);
    emit CreateLab(msg.sender);
  }
  function getLabAddress() public view returns (address){
    return labAddr;
  }
  function isCompleted() public view returns (bool){
    return lab.isCompleted();
  }
}