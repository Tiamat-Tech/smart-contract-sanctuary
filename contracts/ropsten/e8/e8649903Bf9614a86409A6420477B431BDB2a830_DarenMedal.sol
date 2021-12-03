// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract DarenMedal is
  ERC721EnumerableUpgradeable,
  OwnableUpgradeable,
  PausableUpgradeable
{
  function initialize() public initializer {
    __ERC721_init("Daren Test Medal Token", "DTM");
    __ERC721Enumerable_init();
    __Ownable_init();
    // Reserve first 30 ponies to contract owner
    // for (uint256 i = 0; i < 30; i++) {
    //   super._mint(msg.sender, totalSupply());
    // }
  }

  function zeng(address account, uint256 tokenId) external onlyOwner {
    _mint(account, tokenId);
  }

  function shao(uint256 tokenId) external onlyOwner {
    _burn(tokenId);
  }

  function hasTokenIdInRange(
    address owner,
    uint256 from,
    uint256 to
  ) external view returns (bool) {
    require(from <= to, "Range to should greater than range from.");

    for (uint256 i = 0; i < balanceOf(owner); i++) {
      uint256 tokenId = tokenOfOwnerByIndex(owner, i);
      if (tokenId >= from && tokenId <= to) {
        return true;
      }
    }
    return false;
  }

  function hasTokenIdInArray(address owner, uint256[] memory list)
    external
    view
    returns (bool)
  {
    require(list.length > 0, "List should not empty.");
    for (uint256 i = 0; i < balanceOf(owner); i++) {
      uint256 tokenId = tokenOfOwnerByIndex(owner, i);

      for (uint256 j = 0; j < list.length; j++) {
        if (tokenId == list[j]) {
          return true;
        }
      }
    }
    return false;
  }
}