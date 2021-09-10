// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC721Pausable.sol";

contract MoodyMonsteras is ERC721Enumerable, Ownable, ERC721Burnable, ERC721Pausable {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;

  uint256 public constant MAX_ELEMENTS = 1000;
  uint256 public constant PRICE = 1 * 10**16;
  uint256 public constant MAX_BY_MINT = 10;
  address public constant creatorAddress = 0xc8799A6b6b78f3409A893bd8dd1f2399a9b05FCf;
  string public baseTokenURI;

  event CreateMonstera(uint256 indexed id);

  constructor(string memory baseURI) ERC721("MoodyMonsteras", "MONSTERA") {
    setBaseURI(baseURI);
    pause(true);
  }

  modifier saleIsOpen {
    require(_totalSupply() <= MAX_ELEMENTS, "Sale end");
    if (_msgSender() != owner()) {
        require(!paused(), "Pausable: paused");
    }
    _;
  }

  // public / external

  function mint(address _to, uint256 _count) public payable saleIsOpen {
    uint256 total = _totalSupply();
    require(total + _count <= MAX_ELEMENTS, "Not Enough Available");
    require(total <= MAX_ELEMENTS, "Sold Out");
    require(_count <= MAX_BY_MINT, "Mint Amount Exceeded");
    require(msg.value >= price(_count), "Value Below Price");

    for (uint256 i = 0; i < _count; i++) {
      _mintAnElement(_to);
    }
  }

  function totalMint() public view returns (uint256) {
    return _totalSupply();
  }

  function price(uint256 _count) public pure returns (uint256) {
    return PRICE.mul(_count);
  }

  function walletOfOwner(address _owner) external view returns (uint256[] memory) {
    uint256 tokenCount = balanceOf(_owner);

    uint256[] memory tokensId = new uint256[](tokenCount);
    for (uint256 i = 0; i < tokenCount; i++) {
      tokensId[i] = tokenOfOwnerByIndex(_owner, i);
    }

    return tokensId;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  // onlyOwner

  function setBaseURI(string memory baseURI) public onlyOwner {
    baseTokenURI = baseURI;
  }

  function pause(bool val) public onlyOwner {
    if (val == true) {
      _pause();
      return;
    }
    _unpause();
  }

  function withdrawAll() public payable onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0);
    _withdraw(creatorAddress, balance);
  }

  // private / internal

  function _totalSupply() internal view returns (uint) {
    return _tokenIds.current();
  }

  function _mintAnElement(address _to) private {
    uint id = _totalSupply();
    _tokenIds.increment();
    _safeMint(_to, id);
    emit CreateMonstera(id);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function _withdraw(address _address, uint256 _amount) private {
    (bool success, ) = _address.call{value: _amount}("");
    require(success, "Transfer failed.");
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

}