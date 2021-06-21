//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";

contract Status {
  string status;
  address public owner;

  constructor(string memory _status) {
    console.log("Deploying a Status with first msg:", _status);
    status = _status;
    owner = msg.sender;
  }

  // Alternatively, make status public - Solidity will construct a getter for it.
  function get_status() public view returns (string memory) {
    return status;
  }

  function set_status(string memory _status) public {
    require(owner == msg.sender, "Only owner can set the status!");
    console.log("Changing status from '%s' to '%s'", status, _status);
    status = _status;
  }
}