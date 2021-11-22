//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract WertTFN is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string private metadataUri = "ipfs://QmNeNeHmFHHaoycvmPgUb8WsmrqJhs78jXxpT6NfQwzkrj/metadata.json";

    constructor() public ERC721("WertTFN", "WTFN") {}

    function mintToken(address to)
      public
      payable
    {
        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _mint(to, tokenId);
    }

    function tokenURI(uint256 tokenId)
      public
      view
      override
      returns (string memory)
    {
      return metadataUri;
    }
}