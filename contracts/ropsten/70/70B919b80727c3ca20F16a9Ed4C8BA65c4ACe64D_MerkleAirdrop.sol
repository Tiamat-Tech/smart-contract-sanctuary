// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

contract MerkleAirdrop is Initializable {
  using SafeERC20 for IERC20;
  using BitMaps for BitMaps.BitMap;

  address public creator;
  address public token;
  bytes32 public merkleRoot;
  uint256 public claimPeriodEnds;
  BitMaps.BitMap private claimed;

  event AirdropClaimed(
    address indexed claimant,
    address indexed token,
    uint256 amount
  );

  constructor() initializer {}

  function initialize(
    address _creator,
    address _token,
    bytes32 _merkleRoot,
    uint256 _claimPeriodEnds
  ) public initializer {
    creator = _creator;
    token = _token;
    merkleRoot = _merkleRoot;
    claimPeriodEnds = _claimPeriodEnds;
  }

  function claimAirdrop(
    uint256 _claimantIndex,
    address _claimant,
    uint256 _amount,
    bytes32[] calldata _merkleProof
  ) external {
    require(
      block.timestamp <= claimPeriodEnds,
      "ERR__CLAIM_PERIOD_ENDED"
    );
    require(
      !isClaimed(_claimantIndex),
      "ERR__AIRDROP_ALREADY_CLAIMED"
    );
    require(
      verifyMerkleProof(
        _claimantIndex,
        _claimant,
        _amount,
        _merkleProof
      ),
      "ERR__INVALID_MERKLE_PROOF"
    );

    claimed.set(_claimantIndex);

    IERC20(token).safeTransfer(_claimant, _amount);

    emit AirdropClaimed(_claimant, token, _amount);
  }

  function isClaimed(uint256 _claimantIndex)
    public
    view
    returns (bool)
  {
    return claimed.get(_claimantIndex);
  }

  function verifyMerkleProof(
    uint256 _claimantIndex,
    address _claimant,
    uint256 _amount,
    bytes32[] calldata _merkleProof
  ) public view returns (bool) {
    bytes32 node = keccak256(
      abi.encodePacked(
        token,
        _claimantIndex,
        _claimant,
        _amount
      )
    );

    return
      MerkleProof.verify(
        _merkleProof,
        merkleRoot,
        node
      );
  }

  function withdrawAirdrop(address _dest) external {
    require(msg.sender == creator, "ERR__UNAUTHORIZED");
    require(
      block.timestamp > claimPeriodEnds,
      "ERR__CLAIM_PERIOD_NOT_ENDED"
    );
    IERC20 _token = IERC20(token);
    uint256 unclaimedBalance = _token.balanceOf(address(this));
    require(unclaimedBalance > 0, "ERR__ZERO_UNCLAIMED_BALANCE");
    _token.safeTransfer(_dest, unclaimedBalance);
  }
}