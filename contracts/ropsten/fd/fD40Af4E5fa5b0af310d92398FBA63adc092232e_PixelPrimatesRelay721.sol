// contracts/PixelPrimates.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PixelPrimates721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PixelPrimatesRelay721 is Ownable {
  using SafeMath for uint256;

  PixelPrimates721 private _contractStorage;
  bool private _isInitialized = false;
  mapping(string => uint256) private _primateLimits;
  mapping(string => uint256) private _primateCount;

  string constant TYPE_A = "typeA";
  string constant TYPE_B = "typeB";
  string constant TYPE_C = "typeC";

  uint256 public primateMintPrice = 35000000 * (10 ^ 9); // 0.035 ETH
  uint256 public itemMintPrice = 5000000 * (10 ^ 9); // 0.005 ETH

  // just incase. Balance for relay contract should always be 0
  function withdraw() external onlyOwner {
    address payable _owner = payable(owner());
    _owner.transfer(address(this).balance);
  }

  function initialize(PixelPrimates721 addr) external onlyOwner {
    require(!_isInitialized, "Contract already initialized");
    _contractStorage = addr;
    _primateLimits[TYPE_A] = 300;
    _primateLimits[TYPE_B] = 300;
    _primateLimits[TYPE_C] = 300;
    _primateCount[TYPE_A] = 0;
    _primateCount[TYPE_B] = 0;
    _primateCount[TYPE_C] = 0;
    _isInitialized = true;
  }

  function updateMintPrice(
    uint256 primateMintPriceGwei,
    uint256 itemMintPriceGwei
  ) public onlyOwner {
    primateMintPrice = primateMintPriceGwei * (10 ^ 9);
    itemMintPrice = itemMintPriceGwei * (10 ^ 9);
  }

  function getPrimateCount(string memory type_)
    external
    view
    returns (uint256)
  {
    return _primateCount[type_];
  }

  function getPrimateLimit(string memory type_)
    external
    view
    returns (uint256)
  {
    return _primateLimits[type_];
  }

  function updateLimits(
    uint256 typeA,
    uint256 typeB,
    uint256 typeC
  ) external onlyOwner {
    _primateLimits[TYPE_A] = typeA;
    _primateLimits[TYPE_B] = typeB;
    _primateLimits[TYPE_C] = typeC;
  }

  function compareStringsbyBytes(string memory s1, string memory s2)
    private
    pure
    returns (bool)
  {
    return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
  }

  function checkIfMintable(uint256 numberOfTokens, string memory primateType)
    private
    pure
  {
    require(
      compareStringsbyBytes(primateType, TYPE_A) ||
        compareStringsbyBytes(primateType, TYPE_B) ||
        compareStringsbyBytes(primateType, TYPE_C),
      "Invalid Primate Type"
    );
    require(numberOfTokens > 0, "number of tokens to mint cannot be 0");
  }

  function checkIfPrimatesMintable(
    uint256 numberOfTokens,
    string memory primateType
  ) private view {
    checkIfMintable(numberOfTokens, primateType);
    require(numberOfTokens <= 10, "Can only mint up to 10 tokens at a time.");
    require(
      _primateCount[primateType] + numberOfTokens <=
        _primateLimits[primateType],
      "Cannot mint more than the current type limit"
    );
    require(
      primateMintPrice.mul(numberOfTokens) <= msg.value,
      "Insufficient ether amount was sent"
    );
  }

  function checkIfItemsMintable(
    uint256 numberOfTokens,
    string memory primateType
  ) private {
    checkIfMintable(numberOfTokens, primateType);
    require(
      itemMintPrice.mul(numberOfTokens) <= msg.value,
      "Insufficient ether amount was sent"
    );
  }

  function mintPrimates(uint256 numberOfTokens, string memory primateType)
    external
    payable
  {
    checkIfPrimatesMintable(numberOfTokens, primateType);
    address sender = msg.sender;
    _primateCount[primateType] += numberOfTokens;
    _contractStorage.mintPrimates{ value: msg.value }(
      sender,
      numberOfTokens,
      primateType
    );
  }

  function mintItems(uint256 numberOfTokens, string memory primateType)
    external
    payable
  {
    checkIfItemsMintable(numberOfTokens, primateType);
    address sender = msg.sender;
    _contractStorage.mintItems{ value: msg.value }(
      sender,
      numberOfTokens,
      primateType
    );
  }
}