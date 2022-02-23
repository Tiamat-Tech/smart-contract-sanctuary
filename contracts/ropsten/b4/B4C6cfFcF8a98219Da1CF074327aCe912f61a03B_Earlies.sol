// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ERC721A.sol";

contract Earlies is ERC721A, Ownable, ReentrancyGuard {
  uint256 public immutable TOTAL_SUPPLY = 10;
  uint256 public immutable MAX_MINT_PER_WALLET = 14;
  mapping(address => uint256) public allowlist;

  constructor() ERC721A("Earlies Society", "ES") {}

  function numberMinted(address owner) public view returns (uint256) {
    return _numberMinted(owner);
  }

  function seedAllowlist(address[] memory addresses, uint256[] memory numSlots)
    external
    onlyOwner
  {
    require(
      addresses.length == numSlots.length,
      "addresses does not match numSlots length"
    );
    for (uint256 i = 0; i < addresses.length; i++) {
      allowlist[addresses[i]] = numSlots[i];
    }
  }

  function mint(uint256 quantity) external payable {
    // _safeMint's second argument now takes in a quantity, not a tokenId.
    require(quantity <= MAX_MINT_PER_WALLET, "You are not allowed to mint more than 14 NFTs per wallet.");
    require(
      numberMinted(msg.sender) + quantity <= MAX_MINT_PER_WALLET,
      "You are not allowed to mint more than 14 NFTs per wallet."
    );
    require(totalSupply() + quantity <= MAX_MINT_PER_WALLET, "There are not enough NFTs left to mint the desired amount.");
    _safeMint(msg.sender, quantity);
  }

  function withdrawMoney() external onlyOwner nonReentrant {
    (bool success, ) = msg.sender.call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }
}