// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract Facts is Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _factsCount;

  struct Fact {
    bool beenDone;
    address author;
    uint256 timestamp;
    uint256 funded;
  }

  mapping (bytes32 => Fact) private _facts;

  uint256 public basePrice;
  uint256 public totalFunded;

  constructor() {
    basePrice = 24000000000000000; //0.024 ETH
  }

  function mint(bytes32 hashOfFact) public payable returns (uint256) {
    require(basePrice <= msg.value, "Eth value sent is not sufficient");
    _factsCount.increment();
    totalFunded += msg.value;

    if (_facts[hashOfFact].beenDone) {
      Fact storage factMetadata = _facts[hashOfFact];
      require(factMetadata.funded + msg.value >= factMetadata.funded, "Overflow");

      _facts[hashOfFact].funded += msg.value;

      return _factsCount.current();
    }

    _facts[hashOfFact] = Fact({
      beenDone: true,
      author: msg.sender, 
      timestamp: block.timestamp,
      funded: msg.value
    });

    return _factsCount.current();
  }

  function balanceOfHash(bytes32 hashOfFact) public view returns (uint256) {
    Fact storage factMetadata = _facts[hashOfFact];
    require(factMetadata.beenDone && factMetadata.author == msg.sender, "Author-fact combination invalid");

    return factMetadata.funded;
  }

  function withdraw(bytes32 hashOfFact, uint256 amount) public {
    Fact storage factMetadata = _facts[hashOfFact];
    require(factMetadata.beenDone && factMetadata.author == msg.sender, "Author-phrase combination invalid");

    uint256 balance = factMetadata.funded;
    require(balance >= amount, "Withdrawal amount must be equivalent to available balance");

    factMetadata.beenDone = false;
    factMetadata.author = address(0);
    factMetadata.timestamp = block.timestamp;
    factMetadata.funded = 0;
    (bool success, ) = msg.sender.call{value: balance}("");
    require(success, "Withdrawal failed");
  }

  function setBasePrice(uint256 updatedBasePrice) public onlyOwner {
    basePrice = updatedBasePrice;
  }
}