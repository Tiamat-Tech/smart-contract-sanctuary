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

contract DooflesToken is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable, Pausable, PaymentSplitter, ReentrancyGuard {
  using SafeMath for uint256;

  uint256 public constant TOKEN_LIMIT = 10000;
  uint internal nonce = 0;
  uint[TOKEN_LIMIT] internal indices;

  uint256 private _tokenPrice;
  uint256 private _maxTokensAtOnce = 50;

  string public baseURIExtended = "https://doofles-api.herokuapp.com/metadata/";

  uint256[] private _teamShares = [33, 33, 34];
  address[] private _team = [ 0xCE81fdDfdEF44EA5d56944c9CCF2D0EA0f7B604C, 0xDAD375f9B26C33bFD780C7a184C2c3290A8EFd6e, 0xfb311e0a12eAE8b95B41225A996e42974F0B66bA ];

  constructor()
    PaymentSplitter(_team, _teamShares)
    ERC721("lesDood", "FDOODLE")
  {
    setTokenPrice(60000000000000000);
  }

  function _baseURI() internal override view returns (string memory) {
    return baseURIExtended;
  }

  function setBaseURI(string memory _newURI) public onlyOwner {
    baseURIExtended = _newURI;
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