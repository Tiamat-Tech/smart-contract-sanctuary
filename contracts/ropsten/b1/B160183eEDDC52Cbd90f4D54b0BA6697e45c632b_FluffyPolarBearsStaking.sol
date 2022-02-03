// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "./PlaceholderNFT.sol";

struct FluffyAttributes {
  address owner;

  bool staked;

  uint256 lastClaimTimestamp;
  uint256 savedReward;
}

contract FluffyPolarBearsStaking is Ownable {

  PlaceholderNFT public erc721Contract;

  mapping(uint256 => FluffyAttributes) public fluffyAttributes;

  constructor(PlaceholderNFT erc721Contract_) {
    erc721Contract = erc721Contract_;
  }

  function _stakeToken(uint256 tokenId, address owner) private {
    FluffyAttributes storage fluffy = fluffyAttributes[tokenId];
    fluffy.owner = owner;
    fluffy.staked = true;
    erc721Contract.transferFrom(owner, address(this), tokenId);
  }

  function stake(uint256[] calldata tokenIds) external payable{
    for (uint256 i = 0; i < tokenIds.length; i++) {
      require(erc721Contract.ownerOf(tokenIds[i]) == msg.sender, "Not the owner of token");
      _stakeToken(tokenIds[i], msg.sender);
    }
  }

  function _unstakeToken(uint256 tokenId) private {
    FluffyAttributes storage fluffy = fluffyAttributes[tokenId];
    fluffy.staked = false;
    erc721Contract.transferFrom(address(this), fluffy.owner, tokenId);
  }

  function unstake(uint256[] calldata tokenIds) external {
    for (uint256 i = 0; i < tokenIds.length; i++) {
      FluffyAttributes storage fluffy = fluffyAttributes[tokenIds[i]];
      require(fluffy.owner == msg.sender, "Not the owner of token");
      _unstakeToken(tokenIds[i]);
    }
  }

}