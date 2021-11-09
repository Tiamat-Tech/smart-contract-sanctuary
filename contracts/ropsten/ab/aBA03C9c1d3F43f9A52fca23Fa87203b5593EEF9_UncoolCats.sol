// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract UncoolCats is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable, Pausable, PaymentSplitter, ReentrancyGuard {
  using SafeMath for uint256;

  uint256 public constant TOKEN_LIMIT = 9933;
  uint internal nonce = 0;
  uint[TOKEN_LIMIT] internal indices;

  uint256 private _tokenPrice;
  uint256 private _maxTokensAtOnce = 50;

  uint256[] private _teamShares = [100];
  address[] private _team = [
    0x306078844120a9e497246F52E8982988b518aa9b
  ];

  constructor()
    PaymentSplitter(_team, _teamShares)
    ERC721("Uncool Cats", "UNCOOL")
  {
    setTokenPrice(20000000000000000);
  }

  function _baseURI() internal override pure returns (string memory) {
    return "ipfs://QmbghDxNYCq2ty22kaFgbzX8PkdpKFwAdxgdaamsAWwJnK/";
  }

  function getTokenPrice() public view returns(uint256) {
    return _tokenPrice;
  }

  function setTokenPrice(uint256 _price) public onlyOwner {
    _tokenPrice = _price;
  }

  function togglePaused() public onlyOwner {
    if (paused()) { _unpause(); } else { _pause(); }
  }

  function _newTokenIndex() internal returns (uint256) {
    uint256 totalSize = TOKEN_LIMIT - totalSupply();
    uint256 index = uint(keccak256(abi.encodePacked(nonce, msg.sender, block.difficulty, block.timestamp))) % totalSize;
    uint256 value = 0;
    if (indices[index] != 0) { value = indices[index]; } else { value = index; }
    if (indices[totalSize-1] == 0) { indices[index] = totalSize-1; } else { indices[index] = indices[totalSize-1]; }
    nonce++;
    return value.add(1);
  }

  function _mintRandom(address _to) private {
    uint _tokenID = _newTokenIndex();
    _safeMint(_to, _tokenID);
  }

  function devMint(uint256 _amount) public payable nonReentrant onlyOwner {
    require(totalSupply().add(_amount) <= TOKEN_LIMIT, "Exceeds max supply of tokens");

    for(uint256 i = 0; i < _amount; i++) {
      _mintRandom(msg.sender);
    }
  }

  function mintMultipleTokens(uint256 _amount) public payable nonReentrant whenNotPaused {
    require(totalSupply().add(_amount) <= TOKEN_LIMIT, "Exceeds max supply of tokens");
    require(_amount <= _maxTokensAtOnce, "Too many tokens");
    require(getTokenPrice().mul(_amount) == msg.value, "Insufficient funds");

    for(uint256 i = 0; i < _amount; i++) {
      _mintRandom(msg.sender);
    }
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
    return string(super.tokenURI(tokenId));
  }

  function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}