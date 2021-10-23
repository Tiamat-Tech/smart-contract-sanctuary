// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SignerTest is Ownable {
    using ECDSA for bytes32;
  address _signerAddress = 0xd4f795fFB126C6E8C01A06C6B213a1063C04b0cc;
  
  mapping(address => uint) reservations;
  
  uint reservationFee = 0.0000001 ether;

  function hashTransaction(address sender, uint256 qty, string memory nonce) public pure returns(bytes32) {
    bytes32 hash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encodePacked(sender, qty, nonce)))
          );
          
        return hash;
    }
    
  function matchAddresSigner(bytes32 hash, bytes memory signature) public view returns(bool) {
      return _signerAddress == hash.recover(signature);
  }

  function getHashAddress(bytes32 hash, bytes memory signature) public pure returns(address) {
    return hash.recover(signature);
  }
  
  function viewSignerAddress() public view returns(address) {
      return _signerAddress;
  }
  
  function setSignerAddress(address _address) public onlyOwner {
      _signerAddress = _address;
  }
  
  function getReservationFee() public view returns(uint) {
      return reservationFee;
  }
  
  function addReservation() public payable {
      require(msg.value >= reservationFee);
      require(reservations[msg.sender] < 5);
      reservations[msg.sender]++;
      if ( msg.value > reservationFee ) {
        address payable sender = payable(msg.sender);
        sender.transfer(msg.value - reservationFee);
      }
  }
  
  function withdraw() public onlyOwner {
      address payable _owner = payable(owner());
      _owner.transfer(address(this).balance);
  }
  
  function getBalance() public view returns(uint) {
      return address(this).balance;
  }
  
  function getNumReservations() public view returns(uint) {
      return reservations[msg.sender];
  }
}