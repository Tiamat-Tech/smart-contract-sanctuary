// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract IMXNFT is ERC721, Mintable {
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;
  mapping(uint256 => string) private _tokenURIs;

  event TokenURI(uint256 indexed tokenId, string indexed tokenUri);

  constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC721("Test NFT", "tNFT") Mintable(_owner, _imx) {}

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal override {
        _safeMint(user, id);
    }

  function mint(address to, uint256 tokenId) public {
    _safeMint(to, tokenId);
  }

  function mintWithUriAutoTokenId(address to, string memory tokenUri) public {
    _tokenIds.increment();
    uint256 tokenId = _tokenIds.current();
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, tokenUri);
  }

  //TODO: Batch/Duplicate mint functions?

  function _setTokenURI(uint256 tokenId, string memory tokenUri) internal {
    _tokenURIs[tokenId] = tokenUri;
    emit TokenURI(tokenId, tokenUri);
  }
}