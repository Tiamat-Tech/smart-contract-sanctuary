pragma solidity >=0.8.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "hardhat/console.sol";
// import "@openzeppelin/contracts/access/Ownable.sol"; 
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol

contract YourContract {

  // event SetPurpose(address sender, string purpose);

  string public uri = "Building Unstoppable Apps!!!";

  constructor() {
    // what should we do on deploy?
  }

  function setUri(string memory newUri) public {
      uri = newUri;
      console.log(msg.sender,"set uri to",uri);
      // emit SetPurpose(msg.sender, purpose);
  }
}