pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";

contract YourContract is Ownable {
  string public purpose = "Building Unstoppable Apps!!!";

  constructor() {
  }

  function setPurpose(string memory newPurpose) public onlyOwner {
      purpose = newPurpose;
  }
}