// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./interfaces/IMerkleAirdrop.sol";

contract MerkleAirdropFactory is Ownable {
  event MerkleAirdropCreated(
    address _merkleAirdropClone,
    address indexed _creator,
    address _token
  );

  address payable public merkleAirdrop;

  constructor(address payable _merkleAirdrop) {
    require(
      _merkleAirdrop != address(0),
      "ERR__MERKLE_AIRDROP_CANNOT_BE_ZERO_ADDRESS"
    );
    merkleAirdrop = _merkleAirdrop;
  }

  function createAirdrop(
    address _tokenAddress,
    bytes32 _merkleRoot,
    uint256 _claimPeriodEnds,
    uint256 _saltNonce
  ) external returns (address) {
    address merkleAirdropClone = Clones.cloneDeterministic(
      merkleAirdrop,
      keccak256(
        abi.encodePacked(
          msg.sender,
          _tokenAddress,
          _merkleRoot,
          _claimPeriodEnds,
          _saltNonce
        )
      )
    );
    IMerkleAirdrop(merkleAirdropClone).initialize(
      msg.sender,
      _tokenAddress,
      _merkleRoot,
      _claimPeriodEnds
    );
    emit MerkleAirdropCreated(merkleAirdropClone, msg.sender, _tokenAddress);
    return merkleAirdropClone;
  }

  function setMerkleAirdropImplAddress(address payable _merkleAirdrop)
    external
    onlyOwner
  {
    require(
      _merkleAirdrop != address(0),
      "ERR__MERKLE_AIRDROP_CANNOT_BE_ZERO_ADDRESS"
    );
    merkleAirdrop = _merkleAirdrop;
  }
}