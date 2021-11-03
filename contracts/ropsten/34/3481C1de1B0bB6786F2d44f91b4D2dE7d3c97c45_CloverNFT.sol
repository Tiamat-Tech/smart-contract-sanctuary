//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CloverNFT is ERC721URIStorage, Ownable {
  enum Color {
    Green,
    Yellow,
    Pink,
    Purple,
    Blue,
    Black
  }

  struct MetaData {
    Color color;
    uint8 charCode;
  }

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  mapping(uint256 => MetaData) private _metaDatas;

  event Minted(address indexed to, uint256 tokenId);
  event Upgraded(uint256[3] fromIds, uint256 newId);

  constructor() ERC721("CloverNFT", "CFT") {}

  function mint(
    address to,
    Color color,
    uint8 charCode
  ) external onlyOwner returns (uint256) {
    MetaData memory meta = MetaData(color, charCode);
    uint256 id = _mintNft(to, meta);
    emit Minted(to, id);
    return id;
  }

  function setTokenURI(uint256 tokenId, string memory _tokenURI)
    external
    onlyOwner
  {
    _setTokenURI(tokenId, _tokenURI);
  }

  function _mintNft(address to, MetaData memory meta)
    internal
    returns (uint256)
  {
    _tokenIds.increment();
    uint256 newId = _tokenIds.current();
    _mint(to, newId);
    _setMeta(newId, meta);

    return newId;
  }

  function _setMeta(uint256 tokenId, MetaData memory meta) private {
    require(_exists(tokenId), "CloverNFT: nonexistent token");
    require(
      meta.charCode >= 65 && meta.charCode <= 90,
      "CloverNFT: invalid char code"
    );

    _metaDatas[tokenId] = meta;
  }

  function metaData(uint256 tokenId) public view returns (MetaData memory) {
    require(_exists(tokenId), "CloverNFT: nonexistent token");
    MetaData memory data = _metaDatas[tokenId];
    return data;
  }

  function upgrade(uint256[3] calldata tokenIds) public returns (uint256) {
    MetaData memory meta = metaData(tokenIds[0]);
    require(
      meta.color != Color.Green && meta.color != Color.Yellow,
      "CloverNFT: can't upgrade"
    );
    require(_isApprovedOrOwner(_msgSender(), tokenIds[0]), "CloverNFT: noperm");

    for (uint256 i = 1; i < tokenIds.length; i++) {
      require(
        _isApprovedOrOwner(_msgSender(), tokenIds[i]),
        "CloverNFT: noperm"
      );
      MetaData memory metaOther = metaData(tokenIds[i]);
      require(meta.charCode == metaOther.charCode, "CloverNFT: diff char");
      require(meta.color == metaOther.color, "CloverNFT: diff color");
    }

    for (uint256 i = 0; i < tokenIds.length; i++) {
      _burn(tokenIds[i]);
    }

    // upgrade direction: Black -> Blue -> Purple -> Pink -> Yellow
    if (meta.color == Color.Black) {
      meta.color = Color.Blue;
    } else if (meta.color == Color.Blue) {
      meta.color = Color.Purple;
    } else if (meta.color == Color.Purple) {
      meta.color = Color.Pink;
    } else if (meta.color == Color.Pink) {
      meta.color = Color.Yellow;
    } else {
      revert("CloverNFT: unexpected");
    }

    uint256 newId = _mintNft(_msgSender(), meta);

    emit Upgraded(tokenIds, newId);

    return newId;
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);
    delete _metaDatas[tokenId];
  }
}