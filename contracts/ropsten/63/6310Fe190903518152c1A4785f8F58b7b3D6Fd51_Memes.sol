// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract Memes is Ownable {
  using Counters for Counters.Counter;
  Counters.Counter public memeCount;

  uint256 public totalContractFunds;
  uint256 public totalContractShares;
  uint256 public baseShareMultiplier;

  constructor() {
    totalContractFunds = 0;
    totalContractShares = 0;
    baseShareMultiplier = 10**18;
  }

  struct Meme {
    bool exists;
    uint256 totalFunds;
    uint256 totalShares;
  }

  // sha256 of string maps to Meme
  mapping(bytes32 => Meme) private memes;

  struct Mymeme {
    bool exists;
    uint256 shares;
    uint256 updatedAtTimestamp;
  }

  // sha256 of (a) hash of the Meme-string and (b) mime's address maps to mymeme 
  mapping(bytes32 => Mymeme) private mymemes;

  function estimateNewMymemeSharesOfMeme(bytes32 hashOfMemeString, uint256 amount) public view returns (uint256) {
    if (!memes[hashOfMemeString].exists) {
      return baseShareMultiplier;
    }

    Meme storage memeData = memes[hashOfMemeString];

    return (amount * memeData.totalShares) / memeData.totalFunds;
  }

  function startMeme(bytes32 hashOfMemeString) public payable returns (uint256) {
    require(!memes[hashOfMemeString].exists, "Meme already exists");
    memeCount.increment();

    totalContractFunds += msg.value;
    totalContractShares += baseShareMultiplier;

    memes[hashOfMemeString] = Meme({
      exists: true,
      totalFunds: msg.value,
      totalShares: baseShareMultiplier
    });

    return memeCount.current();
  }

  function imitate(bytes32 hashOfMemeString) public payable returns (uint256) {
    require(memes[hashOfMemeString].exists, "Meme does not exist yet");

    Meme storage memeData = memes[hashOfMemeString];

    uint256 newMymemeShares = (msg.value * memeData.totalShares) / memeData.totalFunds;
    uint256 newTotalShares = memeData.totalShares + newMymemeShares;

    bytes32 mymemeHash = getMymemeHash(hashOfMemeString, msg.sender);

    totalContractFunds += msg.value;
    totalContractShares += newMymemeShares;

    memeData.totalShares = newTotalShares;
    memeData.totalFunds = msg.value + memeData.totalFunds;

    if (mymemes[mymemeHash].exists) {
      Mymeme storage mymemeData = mymemes[mymemeHash];

      mymemeData.shares += newMymemeShares;
      mymemeData.updatedAtTimestamp = block.timestamp;

      return mymemeData.shares;
    }

    mymemes[mymemeHash] = Mymeme({
      exists: true,
      shares: newMymemeShares,
      updatedAtTimestamp: block.timestamp
    });

    return newMymemeShares;
  }

  function withdrawFromMeme(bytes32 hashOfMemeString) public returns (bool) {
    require(memes[hashOfMemeString].exists, "Meme does not exist yet");

    Meme storage memeData = memes[hashOfMemeString];
    require(memeData.totalShares > 0, "Meme must have positive share count");
    require(memeData.totalFunds > 0, "Meme must be funded");

    bytes32 mymemeHash = getMymemeHash(hashOfMemeString, msg.sender);
    require(mymemes[mymemeHash].exists, "Mymeme does not exist yet");

    Mymeme storage mymemeData = mymemes[mymemeHash];
    require(mymemeData.shares > 0, "Mymeme must have positive share count");

    uint256 balanceAvailable = (mymemeData.shares * memeData.totalFunds) / memeData.totalShares;

    memeData.totalShares -= mymemeData.shares;

    memeData.totalFunds -= balanceAvailable;

    mymemeData.shares = 0;
    mymemeData.exists = false;
    // n.b., if exists == false and updatedAt is non-zero, mymeme was withdrawn
    mymemeData.updatedAtTimestamp = block.timestamp;

    (bool success, ) = msg.sender.call{value: balanceAvailable}("");
    require(success, "Withdrawal failed");
    return success;
  }

  function getMemeHash(string memory memeString) public pure returns (bytes32) {
    return sha256(abi.encodePacked(memeString));
  }

  function getMymemeHash(bytes32 hashOfMemeString, address mime) public pure returns (bytes32) {
    return sha256(abi.encodePacked(hashOfMemeString, mime));
  }

  function getMemeExistence(bytes32 hashOfMemeString) public view returns (bool) {
    return memes[hashOfMemeString].exists;
  }

  function getMemeShares(bytes32 hashOfMemeString) public view returns (uint256) {
    return memes[hashOfMemeString].totalShares;
  }

  function getMemeTotalFunds(bytes32 hashOfMemeString) public view returns (uint256) {
    return memes[hashOfMemeString].totalFunds;
  }

  function getMymemeExistence(bytes32 mymemeHash) public view returns (bool) {
    return mymemes[mymemeHash].exists;
  }

  function getMymemeShares(bytes32 mymemeHash) public view returns (uint256) {
    return mymemes[mymemeHash].shares;
  }
  
  function getMymemeUpdatedAtTimestamp(bytes32 mymemeHash) public view returns (uint256) {
    return mymemes[mymemeHash].updatedAtTimestamp;
  }

  function getTotalContractShares() public view returns (uint256) {
    return totalContractShares;
  }

  function getTotalContractFunds() public view returns (uint256) {
    return totalContractFunds;
  }
}