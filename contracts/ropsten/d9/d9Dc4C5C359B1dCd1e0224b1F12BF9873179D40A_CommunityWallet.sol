// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CommunityWallet is Ownable {
  using ECDSA for bytes32;

  event EthDeposited(uint256 amount);
  event EthClaimed(string nonce, uint256 amount);

  mapping(string => bool) private _usedNonces;

  function deposit() public payable onlyOwner{
      emit EthDeposited(msg.value);
  }

  function claim(uint256 _amount, string memory _nonce, bytes memory _signature) public {
      address signer = recoverSigner(_amount, _nonce, _signature);
      require(signer == owner(), "Not authorized to claim");
      require(!_usedNonces[_nonce], "Not authorized to claim");

      require(_amount > 0, "There is no amount left to claim");
      require(payable(msg.sender).send(_amount));

      _usedNonces[_nonce] = true;

      emit EthClaimed(_nonce, _amount);
  }

  function recoverSigner(uint256 _amount, string memory nonce, bytes memory _signature) private pure returns (address){
      return keccak256(abi.encodePacked(_amount, nonce)).toEthSignedMessageHash().recover(_signature);
  }
}