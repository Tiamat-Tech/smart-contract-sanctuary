// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract Phrases is Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _phrasesCount;

  struct Phrase {
    bool beenDone;
    address author;
    uint256 timestamp;
    uint256 funded;
  }

  mapping (bytes32 => Phrase) private _phrases;

  uint256 public basePrice;
  uint256 public totalFunded;

  constructor() {
    basePrice = 24000000000000000; //0.024 ETH
  }

  function mint(string memory phrase) public payable returns (uint256) {
    require(currentPriceToMint(phrase) <= msg.value, "Eth value sent is not sufficient");
    bytes32 hashOfPhrase = sha256(abi.encodePacked(phrase));
    _phrasesCount.increment();
    totalFunded += msg.value;

    if (_phrases[hashOfPhrase].beenDone) {
      Phrase storage phraseMetadata = _phrases[hashOfPhrase];
      require(phraseMetadata.funded + msg.value >= phraseMetadata.funded, "Overflow");

      _phrases[hashOfPhrase].funded += msg.value;

      return _phrasesCount.current();
    }

    _phrases[hashOfPhrase] = Phrase({
      beenDone: true,
      author: msg.sender, 
      timestamp: block.timestamp,
      funded: msg.value
    });

    return _phrasesCount.current();
  }

  function balanceOfPhrase(string memory phrase) public view returns (uint256) {
    bytes32 hashOfPhrase = sha256(abi.encodePacked(phrase));
    Phrase storage phraseMetadata = _phrases[hashOfPhrase];
    require(phraseMetadata.beenDone && phraseMetadata.author == msg.sender, "Author-phrase combination invalid");

    return phraseMetadata.funded;
  }

  function withdraw(string memory phrase, uint256 amount) public {
    bytes32 hashOfPhrase = sha256(abi.encodePacked(phrase));
    Phrase storage phraseMetadata = _phrases[hashOfPhrase];
    require(phraseMetadata.beenDone && phraseMetadata.author == msg.sender, "Author-phrase combination invalid");

    uint256 balance = phraseMetadata.funded;
    require(balance >= amount, "Withdrawal amount must be equivalent to available balance");

    phraseMetadata.beenDone = false;
    phraseMetadata.author = address(0);
    phraseMetadata.timestamp = block.timestamp;
    phraseMetadata.funded = 0;
    (bool success, ) = msg.sender.call{value: balance}("");
    require(success, "Withdrawal failed");
  } 

  function currentPriceToMint(string memory phrase) public view returns (uint256) {
    uint256 byteLengthOfPhrase = bytes(phrase).length;
    return basePrice * byteLengthOfPhrase;
  }

  function setBasePrice(uint256 updatedBasePrice) public onlyOwner {
    basePrice = updatedBasePrice;
  }
}