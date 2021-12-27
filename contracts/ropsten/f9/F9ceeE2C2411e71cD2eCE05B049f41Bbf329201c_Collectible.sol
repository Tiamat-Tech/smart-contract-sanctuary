// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Collectible is ERC721URIStorage, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  mapping(string => bool) private _collectibleExists;
  mapping(address => uint256[]) private _collection;
  mapping(address => mapping(uint256 => bool)) private _collectionExists;
  mapping(uint256 => bool) private _tokenUnlocks;
  uint256[] private _listOfTokenUnlocks;

  constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

  function getCollectionLength() public view returns (uint256) {
    return _tokenIds.current();
  }

  function totalSupply() public view returns (uint256) {
    return _tokenIds.current();
  }

  function getTokenUnlocks() public view returns (uint256[] memory) {
    return _listOfTokenUnlocks;
  }

  function mint(string memory _tokenUri) public {
    require(!_collectibleExists[_tokenUri], "This is minted already");

    _collectibleExists[_tokenUri] = true;
    _mintTokenUri(_msgSender(), _tokenUri);

    _collection[_msgSender()].push(_tokenIds.current());
  }

  function multiMint(uint256 num) public onlyOwner {
    uint256 supply = totalSupply();
    require(supply + num <= 1000, "Exceed collection limit");
    for (uint256 index = supply; index < supply + num; index++) {
      mint(_getBoxUri(index + 1));
    }
  }

  function getCollection() public view returns (uint256[] memory) {
    return _collection[_msgSender()];
  }

  function _getBoxUri(uint256 boxId) public pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          "https://gateway.pinata.cloud/ipfs/QmXEQdLbpHptdNho32Ckg9mCkhzfHpWQXNgdyH5pffyLSE/box_",
          Strings.toString(boxId),
          ".json"
        )
      );
  }

  function _getBaseUri(uint256 tokenId) public pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          "https://gateway.pinata.cloud/ipfs/QmYMTqTmx93jWfGuFqwxDKTjQKqGgeWr6XqoJpYQy3yP19/",
          Strings.toString(tokenId),
          ".json"
        )
      );
  }

  function _mintTokenUri(address to, string memory url) private {
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    _safeMint(to, newItemId);
    _setTokenURI(newItemId, url);
    _collectionExists[_msgSender()][_tokenIds.current()] = true;
  }

  function unlock(uint256 tokenId) public {
    require(!_tokenUnlocks[tokenId], "This is minted already");
    _setTokenURI(tokenId, _getBaseUri(tokenId));
    _tokenUnlocks[tokenId] = true;
    _listOfTokenUnlocks.push(tokenId);
  }
}