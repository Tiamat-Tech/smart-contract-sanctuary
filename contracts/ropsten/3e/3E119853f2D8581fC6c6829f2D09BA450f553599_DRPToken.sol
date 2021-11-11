// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

//       _____              __                           __
//     _/ ____\_ __   ____ |  | __ __________ __   ____ |  | __
//     \   __\  |  \_/ ___\|  |/ / \___   /  |  \_/ ___\|  |/ /
//      |  | |  |  /\  \___|    <   /    /|  |  /\  \___|    <
//      |__| |____/  \___  >__|_ \ /_____ \____/  \___  >__|_ \
//                       \/     \/       \/           \/     \/
//
//     DRP + Pellar 2021
//     Drop 2 - VR001

contract DRPToken is ERC721Enumerable, Ownable {

  using Strings for uint256;

  // constants
  uint8 public constant MAX_NORMAL_SUPPLY = 88;
  uint256 public constant TETHER_PRICE = 0.00001 ether;

  mapping (uint16 => uint16) private randoms;
  uint16 public boundary = MAX_NORMAL_SUPPLY;

  bool public salesActive = false;

  string public baseURI_A1 = "ipfs://Qme1kTg6wxKh9NmBfMkyxvvEDKsUJQWdyjAtMSaC2Fft7f";

  constructor() ERC721('DRPToken', 'DRP') {
  }

  function toggleActive() external onlyOwner {
    salesActive = !salesActive;
  }

  function setTokenURI(
    string calldata _uri_A1
  ) external onlyOwner {
    baseURI_A1 = _uri_A1;
  }

  function claim(uint16 amount) external payable {
    require(salesActive, "Claim is not active");
    require(tx.origin == msg.sender, "Claim cannot be made from a contract");
    require(boundary >= amount, "Claim: Sorry, we have sold out.");
    require(msg.value >= (amount * TETHER_PRICE), "Claim: Ether value incorrect.");

    for (uint256 i = 0; i < amount; i++) {
      uint16 index = uint16(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.coinbase, msg.sender, totalSupply(), address(this)))) % boundary) + 1; // 1 -> 88
      uint16 tokenId = randoms[index] > 0 ? randoms[index] - 1 : index - 1;
      randoms[index] = randoms[boundary] > 0 ? randoms[boundary] : boundary;
      boundary = boundary - 1;

      _safeMint(msg.sender, tokenId);
    }
  }

  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory){
    require(_exists(_tokenId), "URI query for non existent token");
    return baseURI_A1;
  }

  function withdraw() public onlyOwner {
    uint balance = address(this).balance;
    require(balance > 0, "Contract balance is 0");
    payable(msg.sender).transfer(balance);
  }
}