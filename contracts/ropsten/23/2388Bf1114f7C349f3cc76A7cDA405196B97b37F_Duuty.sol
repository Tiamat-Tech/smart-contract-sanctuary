/**
 *Submitted for verification at Etherscan.io on 2021-12-02
*/

pragma solidity ^0.5.0;


contract Duuty {

  mapping(uint256 => bytes32[]) public images;
  uint256 public counter = 0;
  
  function uploadImage(bytes32[] memory data) public {
    images[counter] = data;
    counter ++;
  }
}