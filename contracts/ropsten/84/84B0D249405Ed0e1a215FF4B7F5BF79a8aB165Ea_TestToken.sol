// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TestToken is ERC721Enumerable, ReentrancyGuard, Ownable {
  using Counters for Counters.Counter;

  constructor(string memory customBaseURI_) ERC721("TestToken", "TTKN") {
    customBaseURI = customBaseURI_;
  }

  /** MINTING LIMITS **/

  mapping(address => uint256) private mintCountMap;

  mapping(address => uint256) private allowedMintCountMap;

  uint256 public constant MINT_LIMIT_PER_WALLET = 5;

  function allowedMintCount(address minter) public view returns (uint256) {
    return MINT_LIMIT_PER_WALLET - mintCountMap[minter];
  }

  function updateMintCount(address minter, uint256 count) private {
    mintCountMap[minter] += count;
  }

  /** MINTING **/

  uint256 public constant MAX_SUPPLY = 2000;

  function mint() public nonReentrant {
    require(saleIsActive, "Sale not active");

    if (allowedMintCount(msg.sender) >= 1) {
      updateMintCount(msg.sender, 1);
    } else {
      revert("Minting limit exceeded");
    }

    require(totalSupply() < MAX_SUPPLY, "Exceeds max supply");

    _mint(msg.sender, totalSupply());
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
}

// Contract created with Studio 721 v1.5.0
// https://721.so