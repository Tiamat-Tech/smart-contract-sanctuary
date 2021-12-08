// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/MerkleProof.sol";

contract Airdrop is Ownable {
  using BitMaps for BitMaps.BitMap;
  using SafeERC20 for IERC20;

  address public token;
  uint256 public claimPeriodEnds;

  bytes32 public merkleRoot;

  BitMaps.BitMap private claimed;

  event MerkleRootChanged(bytes32 merkleRoot);
  event Claim(address indexed claimant, uint256 amount);

  constructor(
    address _owner,
    address _token,
    uint256 _claimPeriodEnds
  ) Ownable() {
    transferOwnership(_owner);
    token = _token;
    claimPeriodEnds = _claimPeriodEnds;
  }

  function claimTokens(
    uint256 amount,
    address delegate,
    bytes32[] calldata merkleProof
  ) external {
    require(block.timestamp < claimPeriodEnds, "Claim period is ended");

    bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
    (bool valid, uint256 index) = MerkleProof.verify(
      merkleProof,
      merkleRoot,
      leaf
    );

    require(valid, "Valid proof");
    require(!isClaimedByIndex(index), "Already claimed");
    claimed.set(index);

    IERC20(token).safeTransfer(delegate, amount);

    emit Claim(msg.sender, amount);
  }

  function sweep(address dest) external onlyOwner {
    require(block.timestamp > claimPeriodEnds, "Claim period not yet ended");

    IERC20 t = IERC20(token);
    t.safeTransfer(dest, t.balanceOf(address(this)));
  }

  function isClaimed(
    uint256 amount,
    address _sender,
    bytes32[] calldata merkleProof
  ) external view returns (bool _isClaimed) {
    bytes32 leaf = keccak256(abi.encodePacked(_sender, amount));
    (bool valid, uint256 index) = MerkleProof.verify(
      merkleProof,
      merkleRoot,
      leaf
    );

    require(valid, "Valid proof");

    _isClaimed = isClaimedByIndex(index);
  }

  function isClaimedByIndex(uint256 index) public view returns (bool) {
    return claimed.get(index);
  }

  function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    require(merkleRoot == bytes32(0), "Merkle root already set");
    merkleRoot = _merkleRoot;
    emit MerkleRootChanged(_merkleRoot);
  }
}