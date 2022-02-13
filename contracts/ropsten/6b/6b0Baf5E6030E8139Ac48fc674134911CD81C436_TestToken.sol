// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TestToken is ERC721, ReentrancyGuard, Ownable {
  using Counters for Counters.Counter;

  constructor(string memory customBaseURI_) ERC721("TestToken", "TTKN") {
    customBaseURI = customBaseURI_;

    allowedMintCountMap[owner()] = 1;
  }

  /** MINTING LIMITS **/

  mapping(address => uint256) private mintCountMap;

  mapping(address => uint256) private allowedMintCountMap;

  function allowedMintCount(address minter) public view returns (uint256) {
    return allowedMintCountMap[minter] - mintCountMap[minter];
  }

  function updateMintCount(address minter, uint256 count) private {
    mintCountMap[minter] += count;
  }

  /** MINTING **/

  uint256 public constant MAX_SUPPLY = 1;

  Counters.Counter private supplyCounter;

  function mint() public nonReentrant onlyOwner {
    if (!saleIsActive) {
      if (allowedMintCount(msg.sender) >= 1) {
        updateMintCount(msg.sender, 1);
      } else {
        revert("Sale not active");
      }
    }

    require(totalSupply() < MAX_SUPPLY, "Exceeds max supply");

    _mint(msg.sender, totalSupply());

    supplyCounter.increment();
  }

  function totalSupply() public view returns (uint256) {
    return supplyCounter.current();
  }

  /** ACTIVATION **/

  bool public saleIsActive = false;

  function setSaleIsActive(bool saleIsActive_) external onlyOwner {
    saleIsActive = saleIsActive_;
  }

  /** URI HANDLING **/

  string private customBaseURI;

  function setBaseURI(string memory customBaseURI_) external onlyOwner {
    customBaseURI = customBaseURI_;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return customBaseURI;
  }

  function tokenURI(uint256) public view override returns (string memory) {
    return _baseURI();
  }
}

// Contract created with Studio 721 v1.5.0
// https://721.so