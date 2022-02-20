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

  struct Mimeme {
    bool exists;
    uint256 shares;
    uint256 updatedAtTimestamp;
  }

  // sha256 of (a) hash of the Meme-string and (b) mime's address maps to mimeme
  mapping(bytes32 => Mimeme) private mimemes;

  function checkExistenceOfMemeString(string memory memeString) public view returns (bool) {
    bytes32 hashOfMemeString = getMemeHash(memeString);
    return memes[hashOfMemeString].exists;
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
    // todo: check multiplier math!
    uint256 newMimemeShares = (msg.value * memeData.totalShares) / memeData.totalFunds;
    uint256 newTotalShares = memeData.totalShares + newMimemeShares;

    bytes32 mimemeHash = getMimemeHash(hashOfMemeString, msg.sender);

    totalContractFunds += msg.value;
    totalContractShares += newMimemeShares;

    memeData.totalShares = newTotalShares;
    memeData.totalFunds = msg.value + memeData.totalFunds;

    if (mimemes[mimemeHash].exists) {
      Mimeme storage mimemeData = mimemes[mimemeHash];

      mimemeData.shares += newMimemeShares;
      mimemeData.updatedAtTimestamp = block.timestamp;

      return mimemeData.shares;
    }

    mimemes[mimemeHash] = Mimeme({
      exists: true,
      shares: newMimemeShares,
      updatedAtTimestamp: block.timestamp
    });

    return newMimemeShares;
  }

  function withdrawFromMeme(bytes32 hashOfMemeString) public returns (bool) {
    require(memes[hashOfMemeString].exists, "Meme does not exist yet");

    Meme storage memeData = memes[hashOfMemeString];
    require(memeData.totalShares > 0, "Meme must have positive share count");
    require(memeData.totalFunds > 0, "Meme must be funded");

    bytes32 mimemeHash = getMimemeHash(hashOfMemeString, msg.sender);
    require(mimemes[mimemeHash].exists, "Mimeme does not exist yet");

    Mimeme storage mimemeData = mimemes[mimemeHash];
    require(mimemeData.shares > 0, "Mimeme must have positive share count");

    uint256 balanceAvailable = (mimemeData.shares / memeData.totalShares) * memeData.totalFunds;

    memeData.totalShares -= mimemeData.shares;

    memeData.totalFunds -= balanceAvailable;

    mimemeData.shares = 0;
    mimemeData.exists = false;
    mimemeData.updatedAtTimestamp = block.timestamp;

    (bool success, ) = msg.sender.call{value: balanceAvailable}("");
    require(success, "Withdrawal failed");
  }

  function getMimemeHash(bytes32 hashOfMemeString, address mime) public pure returns (bytes32) {
    return sha256(abi.encodePacked(hashOfMemeString, mime));
  }

  function getMemeHash(string memory memeString) public pure returns (bytes32) {
    return sha256(abi.encodePacked(memeString));
  }

  function getMimemeShares(string memory memeString, address mime) public view returns (uint256) {
    bytes32 hashOfMemeString = getMemeHash(memeString);
    bytes32 mimemeHash = getMimemeHash(hashOfMemeString, mime);
    return mimemes[mimemeHash].shares;
  }

  function getMemeShares(string memory memeString) public view returns (uint256) {
    bytes32 hashOfMemeString = getMemeHash(memeString);
    return memes[hashOfMemeString].totalShares;
  }

  function getMemeTotalFunds(string memory memeString) public view returns (uint256) {
    bytes32 hashOfMemeString = getMemeHash(memeString);
    return memes[hashOfMemeString].totalFunds;
  }

  function getTotalContractShares() public view returns (uint256) {
    return totalContractShares;
  }

  function getTotalContractFunds() public view returns (uint256) {
    return totalContractFunds;
  }
  
  // ****** ****** ****** ****** ****** ******
}