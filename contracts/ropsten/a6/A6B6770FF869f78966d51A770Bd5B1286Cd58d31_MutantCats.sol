// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// import "solidity-util/lib/Strings.sol";

contract MutantCats is ERC721URIStorage, Ownable {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  constructor() ERC721("MutantCats", "MUTCATS") {}

  function mint(address receiver) external returns (uint256) {
    _tokenIds.increment();
    string memory _tokenURI = string(
      abi.encodePacked(
        "ipfs://QmXZEBJJ6d9D6DU9yYQG1pJMKsUYcUso662HAgyo1wjWoa/",
        Strings.toString(((_tokenIds.current() % 9999) + 1)),
        ".json"
      )
    );
    uint256 newNftTokenId = _tokenIds.current();
    _mint(receiver, newNftTokenId);
    _setTokenURI(newNftTokenId, _tokenURI);

    return newNftTokenId;
  }
}