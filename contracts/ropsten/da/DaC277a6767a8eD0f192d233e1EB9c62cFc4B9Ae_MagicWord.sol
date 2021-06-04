//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;


import "hardhat/console.sol";
import "./BlockTimestamp.sol";


contract MagicWord is BlockTimestamp {

  address payable public owner;

  uint256 public contractTimeLimit;

  event Log(address indexed sender, string message, uint balance);

  constructor() {
    owner = msg.sender;
    // You have 3 weeks to send the magic word to unlock the funds
    contractTimeLimit = block.timestamp + 1814400;
    console.log("Initialized MagicWord contract owned by", msg.sender);
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  function withdrawToOwner() public onlyOwner {
    emit Log(msg.sender, "owner_withdraw", address(this).balance);
    payable(owner).transfer(address(this).balance);
  }

  function _hashInput(string memory _input) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(_input));
  }

  function _compare(string memory _input) private pure returns (bool) {
    return _hashInput(_input) == 0x2e64e7241dbb263bc67206e609564a190dfe66e4ce4ef3adaed91a9655b7e0a5;
  }

  function guessSecret(string memory _input) public {
    if (_blockTimestamp() >= contractTimeLimit) {
      revert("Time to guess the secret expired!");
    }

    if (_compare(_input)) {
      emit Log(msg.sender, "secret_correct", address(this).balance);
      payable(msg.sender).transfer(address(this).balance);
    } else {
      emit Log(msg.sender, "secret_incorrect", 0);
      revert("Invalid input string. Try again!");
    }
  }

  receive() external payable {
    emit Log(msg.sender, "funds_deposited", msg.value);
  }
}