//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";

contract Status {
  string status;
  address owner;

  constructor(string memory _status) {
    console.log("NO HALO: ", _status);
    status = _status;
    owner = msg.sender;
  }

  // Alternatively, make status public - Solidity will construct a getter for it.
  function get_status() public view returns (string memory) {
    return status;
  }

  function set_status(string memory _status) public {
    require(owner == msg.sender, "Nice try:)");
    console.log("Changing status from '%s' to '%s'", status, _status);
    status = _status;
  }
}