// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './Splitter.sol';


contract Factory {
  address[] public contracts;
  event ChildContractCreated(address indexed splitterContractAddress);

  function getContractCount() public view returns(uint) {
    return contracts.length;
  }

  function registerContract(address owner, address payable[] memory _payee, uint256[] memory _share) public returns (address) {
    Splitter c = new Splitter(false, _payee, _share);
    contracts.push(address(c));
    emit ChildContractCreated(address(c));
    c.transferOwnership(owner);
    return address(c);
  }
}