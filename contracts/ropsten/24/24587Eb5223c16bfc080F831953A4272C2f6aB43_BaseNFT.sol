// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "../lib/Operatorable.sol";

contract BaseNFT is ERC721Enumerable, ERC721URIStorage, Operatorable {
  // Base token URI
  string public baseTokenURI;
  // Last token ID starting from 1
  uint256 public tokenID;
  // wallet address => blacklisted status
  mapping(address => bool) public blacklist;

  event LogBlacklistAdded(address indexed account);
  event LogBlacklistRemoved(address indexed account);
  event LogMinted(uint256 indexed tokenId);
  event LogBurnt(uint256 indexed tokenId);

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _baseTokenURI
  ) ERC721(_name, _symbol) {
    baseTokenURI = _baseTokenURI;
  }

  /**
    * @dev Set `baseTokenURI`
    * Only `owner` can call
    */
  function setBaseTokenURI(string memory _baseTokenURI) external onlyOwner {
    baseTokenURI = _baseTokenURI;
  }

  /**
    * @dev Add wallet to blacklist
    * `_account` must not be zero address
    */
  function addBlacklist(address[] memory _accounts) external onlyOwner {
    for (uint256 i = 0; i < _accounts.length; i++) {
      if (_accounts[i] != address(0) && !blacklist[_accounts[i]]) {
        blacklist[_accounts[i]] = true;

        emit LogBlacklistAdded(_accounts[i]);
      }
    }
  }

  /**
    * @dev Remove wallet from blacklist
    */
  function removeBlacklist(address[] memory _accounts) external onlyOwner {
    for (uint256 i = 0; i < _accounts.length; i++) {
      if (blacklist[_accounts[i]]) {
        blacklist[_accounts[i]] = false;

        emit LogBlacklistRemoved(_accounts[i]);
      }
    }
  }

  /**
    * @dev Mint a new token
    * Only `operator` can call
    * `_account` must not be zero address
    * `_account` must not be blacklisted
    * `_uri` can be empty
    */
  function mint(address _account, string memory _uri) external onlyOperator whenNotPaused {
    uint256 newTokenId = ++tokenID;
    super._mint(_account, newTokenId);
    super._setTokenURI(newTokenId, _uri);

    emit LogMinted(newTokenId);
  }

  /**
    * @dev Burn tokens
    * Only `operator` can call
    * `_tokenId` must be valid
    */
  function burn(uint256 _tokenId) external onlyOperator whenNotPaused {
    require(super._exists(_tokenId), "BaseNFT: TOKEN_ID_INVALID");
    _burn(_tokenId);
  }

  function supportsInterface(bytes4 _interfaceId) public view virtual override(AccessControl, ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(_interfaceId);
  }

  /**
    * @dev Return token URI
    * Override {ERC721URIStorage:tokenURI}
    */
  function tokenURI(uint256 _tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
    return ERC721URIStorage.tokenURI(_tokenId);
  }

  /**
    * @dev Disable token transfer from blacklisted wallets
    */
  function _beforeTokenTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) internal override(ERC721, ERC721Enumerable) whenNotPaused {
    require(!blacklist[_from] && !blacklist[_to], "BaseNFT: TOKEN_TRANSFER_DISABLED");
    ERC721Enumerable._beforeTokenTransfer(_from, _to, _tokenId);
  }

  /**
    * @dev Override {ERC721URIStorage:_burn}
    */
  function _burn(uint256 _tokenId) internal override(ERC721, ERC721URIStorage) {
    ERC721URIStorage._burn(_tokenId);

    emit LogBurnt(_tokenId);
  }

  /**
    * @dev Return base URI
    * Override {ERC721:_baseURI}
    */
  function _baseURI() internal view override returns (string memory) {
    return baseTokenURI;
  }
}