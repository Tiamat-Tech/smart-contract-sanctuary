// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol"; // Contains the ERC721 inside

/**
 * NFT template class, with a defined maximum supply and where all minted NFT have the same owner and tokenURI.
 * Owner: intended to be a factory of NFT templates
 * TokenURI: Constant, all minted NFT remain the same
 */
contract NFTClass is ERC721URIStorage {

  uint24 private _tokenId;
  uint24 private _maxSupply;
  address private _contractOwner;
  string private _tokenURITemplate;

  modifier onlyOwner() {
      require(_contractOwner == msg.sender, "Only contract creator can call this function");
      _;
  }

  constructor(string memory nameParam, string memory symbolParam, uint24 maxSupply, address contractOwner, string memory tokenURI) ERC721(nameParam, symbolParam) {
    _maxSupply = maxSupply;
    _contractOwner = contractOwner;
    _tokenURITemplate = tokenURI;
  }

  function mint(address receiver) public onlyOwner {

    require(_tokenId < _maxSupply, "Can't mint more items than specified");

    _tokenId = _tokenId + 1;

    _safeMint(receiver, _tokenId);
    _setTokenURI(_tokenId, _tokenURITemplate);
  }
}