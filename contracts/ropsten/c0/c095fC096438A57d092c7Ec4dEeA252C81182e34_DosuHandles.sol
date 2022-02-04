// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DosuHandles is ERC721, Ownable {
  using Counters for Counters.Counter;

  Counters.Counter public tokenId;

  mapping(uint256 => string) public handles;
  mapping(string => bool) public isRegistered;

  constructor() ERC721("Dosu Handles", "DOSU HANDLE") {}

  function mint(address _to, string memory _handle) public {
    bytes memory handleBytes = bytes(_handle);
    require(handleBytes.length > 0, "Handle length must be greather than 1 symbol");
    require(isRegistered[_handle] == false, "Handle is already registered");

    uint256 _tokenId = tokenId.current();
    _safeMint(_to, _tokenId);

    handles[_tokenId] = _handle;
    isRegistered[_handle] = true;
    tokenId.increment();
  }

  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory handle = handles[_tokenId];

    return handle;
  }
}