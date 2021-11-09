// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract LeBaiser is ERC721URIStorage, IERC721Enumerable {

  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;
  mapping(string => uint8) hashes;
  
  address public constant CREATOR = 0x3ee718Db9be43FB3986b003348479940bbCA80E0;
  address public constant BELOVED = 0xB8A56F7ECab67A98da41E0B398aAf2F9f789FBFc;

  // ERC721Enumerable
  mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
  mapping(uint256 => uint256) private _ownedTokensIndex;
  uint256[] private _allTokens;
  mapping(uint256 => uint256) private _allTokensIndex;

  constructor() ERC721("LeBaiser", "LB") {
    _unsafeAwardItem(BELOVED, "QmY1nnXy7cR1aJ8zB8Wj12bhv9AFdYFvWN18mvoLCZeFem");
  }

  function _baseURI() internal view virtual override returns (string memory) {
      return "ipfs://";
  }

  function awardItem(address recipient, string memory hash) public returns (uint256) {
    require(msg.sender == CREATOR);
    require(hashes[hash] != 1);
    return _unsafeAwardItem(recipient, hash);
  }

  function _unsafeAwardItem(address recipient, string memory hash) internal returns (uint256) {
    hashes[hash] = 1;
    _tokenIds.increment();
    uint256 newItemId = _tokenIds.current();
    _mint(recipient, newItemId);
    _setTokenURI(newItemId, hash);
    return newItemId;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
      return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
  }

  function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
      require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
      return _ownedTokens[owner][index];
  }

  function totalSupply() public view virtual override returns (uint256) {
      return _allTokens.length;
  }

  function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
      require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
      return _allTokens[index];
  }

  function _beforeTokenTransfer(
      address from,
      address to,
      uint256 tokenId
  ) internal virtual override {
      super._beforeTokenTransfer(from, to, tokenId);

      if (from == address(0)) {
          _addTokenToAllTokensEnumeration(tokenId);
      } else if (from != to) {
          _removeTokenFromOwnerEnumeration(from, tokenId);
      }
      if (to == address(0)) {
          _removeTokenFromAllTokensEnumeration(tokenId);
      } else if (to != from) {
          _addTokenToOwnerEnumeration(to, tokenId);
      }
  }

  function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
      uint256 length = ERC721.balanceOf(to);
      _ownedTokens[to][length] = tokenId;
      _ownedTokensIndex[tokenId] = length;
  }

  function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
      _allTokensIndex[tokenId] = _allTokens.length;
      _allTokens.push(tokenId);
  }

  function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {

      uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
      uint256 tokenIndex = _ownedTokensIndex[tokenId];

      if (tokenIndex != lastTokenIndex) {
          uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

          _ownedTokens[from][tokenIndex] = lastTokenId; 
          _ownedTokensIndex[lastTokenId] = tokenIndex;
      }

      delete _ownedTokensIndex[tokenId];
      delete _ownedTokens[from][lastTokenIndex];
  }

  function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {

      uint256 lastTokenIndex = _allTokens.length - 1;
      uint256 tokenIndex = _allTokensIndex[tokenId];

      uint256 lastTokenId = _allTokens[lastTokenIndex];

      _allTokens[tokenIndex] = lastTokenId;
      _allTokensIndex[lastTokenId] = tokenIndex;

      delete _allTokensIndex[tokenId];
      _allTokens.pop();
  }

}