// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./Trustable.sol";

contract NftExample is ERC721Enumerable, Trustable {
  using EnumerableSet for EnumerableSet.UintSet;
  using Counters for Counters.Counter;

  struct Type {
    uint id;
    uint bonus;
  }

  Counters.Counter private nextTokenId;
  EnumerableSet.UintSet private typeIds;
  mapping(uint => Type) private typeById;
  mapping(uint => uint) private typeIdByTokenId;

  constructor() public ERC721("Nft-Example", "NFT") {}

  function create(address holder, uint typeId) public onlyTrusted returns (uint256 tokenId) {
    nextTokenId.increment();
    tokenId = nextTokenId.current();

    typeIdByTokenId[tokenId] = typeId;
    _mint(holder, tokenId);
  }

  function addType(uint id, uint bonus) public onlyTrusted {
    require(!typeIds.contains(id), "id already exists");
    typeIds.add(id);
    typeById[id] = Type(id, bonus);
  }

  function changeType(uint tokenId, uint toTypeId) public onlyTrusted {
    typeIdByTokenId[tokenId] = toTypeId;
  }

  function removeType(uint id) public onlyTrusted {
    require(typeIds.contains(id), "id does not exists");
    typeIds.remove(id);
  }

  function getTypeById(uint id) public view returns (Type memory) {
    return typeById[id];
  }

  function getTypeByTokenId(uint id) public view returns (Type memory) {
    return typeById[typeIdByTokenId[id]];
  }

  function getTypeCount() public view returns (uint) {
    return typeIds.length();
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return "https://www.google.com/search?q=";
  }
}