// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC721CustomTokenURI.sol";
import "./ERC721TieredSupply.sol";
import "./ERC721BasicIpfsStore.sol";
import "./ERC2981TokenBased.sol";

/// @custom:security-contact [email protected]
contract PlaybiteAsset is ERC721, ERC721Enumerable, ERC721CustomTokenURI, ERC721Burnable, AccessControl, ERC721TieredSupply, ERC721BasicIpfsStore, ERC2981TokenBased {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  uint32 private _defaultRoyaltyPercent = 250;

  constructor() ERC721("PlaybiteAsset", "ASSET") {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MINTER_ROLE, msg.sender);
  }

  /**
    * @dev Mints a new batch of asset NFTs that will be owned by `to` and sets the asset tier.
    *
    * Requirements:
    *
    * - `tier` must not be different than previously minted for the same `assetHash`.
    * - Supply for the asset tier must not be exceeded.
  */
  function mintAssetBatch(address to, uint8 tier, string memory assetHash, uint256 count) public onlyRole(MINTER_ROLE) checkTier(tier, assetHash, count) {
    for (uint index = 0; index < count; index++) {
      _mintAsset(to, assetHash);  
    }

    _setMintTier(tier, assetHash, count);
  }

  /**
    * @dev Mints a new asset NFT that will be owned by `to` and sets the asset tier.
    *
    * Requirements:
    *
    * - `tier` must not be different than previously minted for the same `assetHash`.
    * - Supply for the asset tier must not be exceeded.
  */
  function mintAsset(address to, uint8 tier, string memory assetHash) public onlyRole(MINTER_ROLE) checkTier(tier, assetHash, 1) {
    _mintAsset(to, assetHash);
    _setMintTier(tier, assetHash, 1);
  }

  /**
    * @dev Returns the maxiumum supply of an asset tier.
  */
  function tierSupply(uint8 tier) public pure override returns(uint) {
    if (tier == 2) { 
      return 100000;
    } else if (tier == 3) {
      return 10000;
    } else if (tier == 4) {
      return 1000;
    } else if (tier == 5) {
      return 10;
    } else if (tier == 6) {
      return 1;
    }
    return super.tierSupply(tier);
  }

  function _mintAsset(address to, string memory assetHash) internal override returns (uint256) {
    uint256 tokenId = super._mintAsset(to, assetHash);
    _setRoyaltyInfo(tokenId, msg.sender, uint16(_defaultRoyaltyPercent));
    return tokenId;
  }

  /**
    * @dev Sets the default royalty percent that's set when an asset is minted.
  */
  function setDefaultRoyaltyPercent(uint16 percent) public onlyRole(DEFAULT_ADMIN_ROLE) {
    require(percent <= 10000, "RoyaltyPercentTooHigh");
    _defaultRoyaltyPercent = uint32(percent);
  }

  function setRoyaltyInfo(uint256 tokenId, address receiver, uint16 percent) public override onlyRole(DEFAULT_ADMIN_ROLE) {
    super.setRoyaltyInfo(tokenId, receiver, percent);
  }

  function _baseURI() internal pure virtual override(ERC721, ERC721BasicIpfsStore) returns (string memory) {
    return super._baseURI();
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721CustomTokenURI, ERC721TieredSupply, ERC721BasicIpfsStore) {
    super._burn(tokenId);
  }

  function tokenURI(uint256 tokenId) public view override(ERC721, ERC721CustomTokenURI, ERC721TieredSupply, ERC721BasicIpfsStore) returns (string memory) {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, AccessControl, ERC2981) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}