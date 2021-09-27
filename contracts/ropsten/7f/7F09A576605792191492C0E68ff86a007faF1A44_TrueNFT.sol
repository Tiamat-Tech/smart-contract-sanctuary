//   ∙∙·▫▫ᵒᴼᵒ▫ₒₒ▫ᵒᴼⓉⓡⓤⓔ ⓃⒻⓉᴼᵒ▫ₒₒ▫ᵒᴼᵒ▫▫·∙∙
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TrueNFT is ERC721 {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() public ERC721("TrueNFT", "TNFT") {

  }
  struct TrueAsset{
    uint256 id;
    address payable creator;
    address tokenAddress;
    string uri;
    uint8 royalty;
  }

  mapping(uint256 => TrueAsset) public TrueAssets;

  function createTrueAsset(string memory uri, uint8 royalty) public returns(uint256){
    require(royalty > 0, "Royalty cannot be zero or smaller than zero");

    _tokenIds.increment();

    uint256 newTrueAssetId = _tokenIds.current();

    _safeMint(payable(msg.sender), newTrueAssetId);

    TrueAssets[newTrueAssetId] = TrueAsset(newTrueAssetId, payable(msg.sender), address(this), uri, royalty);

    return newTrueAssetId;
  }

function createTrueAssetBundle(string memory uri, uint8 royalty, uint256 quantity) public returns(uint256[] memory){
    require(royalty > 0, "Royalty cannot be zero or smaller than zero");
    require(quantity > 1, "Bundle Quantity cannot be 1 or smaller than 1");
    
    uint256[] memory _trueAssetIds = new uint256[](quantity);
    
    for (uint i=0; i<quantity; i++) {

        _tokenIds.increment();

        uint256 newTrueAssetId = _tokenIds.current();

        _safeMint(payable(msg.sender), newTrueAssetId);

        TrueAssets[newTrueAssetId] = TrueAsset(newTrueAssetId, payable(msg.sender), address(this), uri, royalty);

        _trueAssetIds[i] = newTrueAssetId;

    }

    return _trueAssetIds;
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    return TrueAssets[tokenId].uri;
  }

  function getRoyalty(uint256 tokenId) external virtual view returns(uint8 royalty){
    require(_exists(tokenId), "ERC721Metadata: Royalty query for nonexistent token");

    return TrueAssets[tokenId].royalty;
  }

  function getCreator(uint256 tokenId) external virtual view returns(address payable creator){
    require(_exists(tokenId), "ERC721Metadata: Creator query for nonexistent token");

    return payable(TrueAssets[tokenId].creator);
  }

  function getAsset(uint256 tokenId) external virtual view returns(TrueAsset memory){
    require(_exists(tokenId), "ERC721Metadata: Description query for nonexistent token");

    return TrueAssets[tokenId];
  }
  
}