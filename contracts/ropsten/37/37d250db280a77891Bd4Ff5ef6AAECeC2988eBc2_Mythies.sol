// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Mythies is ERC721Enumerable, ERC721URIStorage, Ownable {
  using SafeMath for uint;
  using Counters for Counters.Counter;

  Counters.Counter private _mintedCount;

  uint256 MAX_SUPPLY = 222;

  // Base URI
  string private _baseURIextended;

  // Events
  event Minted(uint tokenId, address recipient);

  // Mappings
  mapping(uint256 => bool) public mythieExists;
  mapping(uint256 => address) public tokenIdToOwner;
  mapping(string => uint256) public tokenURItoTokenId;
  mapping(uint256 => string) internal _tokenURIs;

  address private _owner;

  constructor() ERC721("Mythies", "MYTHIE") {
    _owner = msg.sender;
  }

  function maxSupply() public view returns (uint) {
    return MAX_SUPPLY;
  }

  function mintedSupply() public view returns (uint) {
    return _mintedCount.current();
  }

  function setBaseURI(string memory baseURI_) external onlyOwner() {
    _baseURIextended = baseURI_;
  }

  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal override {
    require(_exists(tokenId), "URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
    super._setTokenURI(tokenId, _tokenURI);
  }

  function _baseURI() internal view override returns (string memory) {
    return _baseURIextended;
  }

  // testing only
  function getBaseURI() public view virtual returns (string memory) {
    return _baseURIextended;
  }

  function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    string memory base = _baseURI();
    string memory ext = '.json';

    super.tokenURI(tokenId);

    // Concatenate the tokenID to the baseURI.
    return string(abi.encodePacked(base, uint2str(tokenId), ext));
  }

  function _setTokenURIforTokenId(uint256 tokenId) internal {
    string memory uri = tokenURI(tokenId);
    _setTokenURI(tokenId, uri);
    tokenURItoTokenId[uri] = tokenId;
  }

  // Add payable
  // window.ethereum.selectedAddress
  function mintMythie(address recipient) public returns (uint256) {
    require(mintedSupply() <= MAX_SUPPLY, "Purchase would exceed max supply of Mythies");
    // require(msg.value >= 0.01, "Not enough ETH sent; check price!");

    _mintedCount.increment();
    uint256 newMythieId = _mintedCount.current();

    require(!_exists(newMythieId), "A Mythie with this ID already exists");
    require(newMythieId <= MAX_SUPPLY, "Requested tokenId exceeds upper bound");

    _safeMint(recipient, newMythieId);
    _setTokenURIforTokenId(newMythieId);

    // Update mappings
    mythieExists[newMythieId] = true;
    tokenIdToOwner[newMythieId] = recipient;

    emit Minted(newMythieId, recipient);

    return newMythieId;
  }

  // https://github.com/provable-things/ethereum-api/issues/102#issuecomment-760008040
  function uint2str(uint256 _i) public pure returns (string memory str) {
    if (_i == 0) { return "0"; }

    uint256 j = _i;
    uint256 length;
    while (j != 0) {
      length++;
      j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length;
    j = _i;
    while (j != 0) {
      bstr[--k] = bytes1(uint8(48 + j % 10));
      j /= 10;
    }
    str = string(bstr);
  }



  /** 
  * @dev Override some conflicting methods so that this contract can inherit 
  * ERC721Enumerable and ERC721URIStorage functionality
  */

  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
    internal
    override(ERC721, ERC721Enumerable)
  {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}