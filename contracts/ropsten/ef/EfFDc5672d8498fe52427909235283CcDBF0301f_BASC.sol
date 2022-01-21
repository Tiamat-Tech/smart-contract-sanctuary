// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract BASC is
  ERC721Pausable,
  ERC721Burnable,
  ERC721Enumerable,
  Ownable
{
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdTracker;
  string public baseTokenURI;
  uint256 public constant PRICE = 0.05 * 10**18;
  uint256 maxSupplyAll;
  uint256 public constant MAX_BY_MINT = 5;
  bool public saleOpen = true;
  bool public canChangeURI = true;
  address private withdrawOwner;

  event Mint(uint256 indexed id);

  constructor(string memory baseURI, address _withdrawOwner) ERC721("Bored Alien Space Club", "BASC") {
    setBaseURI(baseURI);
    withdrawOwner = _withdrawOwner;
    maxSupplyAll = 30;
  }

  modifier saleIsOpen {
    require(_totalSupply() <= maxSupplyAll, "Sale end");
    if (_msgSender() != owner()) {
      require(saleOpen, "saleIsOpen: sale not open");
    }
    _;
  }

  function _totalSupply() internal view returns (uint) {
    return _tokenIdTracker.current();
  }

  function totalMint() public view returns (uint256) {
    return _totalSupply();
  }

  function price(uint256 _count) public pure returns (uint256) {
    return PRICE.mul(_count);
  }

  function getMaxSupply() public view returns(uint256) {
    return maxSupplyAll;
  }

  function setMaxSupply(uint256 amount) public onlyOwner {
    maxSupplyAll = amount;
  }

  function setBaseURI(string memory baseURI) public onlyOwner {
    require(canChangeURI, "Ability to change URI was revoked");
    baseTokenURI = baseURI;
  }

  function withdraw() external onlyOwner {
    payable(withdrawOwner).transfer(address(this).balance);
  }

  function mint(address _to, uint256 _count) public payable saleIsOpen {
    uint256 total = _totalSupply();
    require(total + _count <= maxSupplyAll, "Max limit");
    require(total <= maxSupplyAll, "Sale end");
    require(_count <= MAX_BY_MINT, "Exceeds number");
    require(_count > 0, "Must be more than 0");
    require(msg.value >= price(_count), "Value below price");

    for (uint256 i = 0; i < _count; i++) {
      _mintAnElement(_to);
    }
  }

  function _mintAnElement(address _to) private {
    uint id = _totalSupply();
    _tokenIdTracker.increment();
    _safeMint(_to, id);
    emit Mint(id);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function walletOfOwner() external view returns (uint256[] memory) {
    address _owner = msg.sender;
    uint256 tokenCount = balanceOf(_owner);

    uint256[] memory tokensId = new uint256[](tokenCount);
    for (uint256 i = 0; i < tokenCount; i++) {
      tokensId[i] = tokenOfOwnerByIndex(_owner, i);
    }

    return tokensId;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 _interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(_interfaceId);
  }

  function revokeSetURIAbility() public onlyOwner {
    canChangeURI = false;
  }

  function flipSaleStatus() public onlyOwner {
    saleOpen = !saleOpen;
  }

  function parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
    bytes memory tmp = bytes(_a);
    uint160 iaddr = 0;
    uint160 b1;
    uint160 b2;
    for (uint256 i = 2; i < 2 + 2 * 20; i += 2) {
      iaddr *= 256;
      b1 = uint160(uint8(tmp[i]));
      b2 = uint160(uint8(tmp[i + 1]));
      if ((b1 >= 97) && (b1 <= 102)) {
        b1 -= 87;
      } else if ((b1 >= 65) && (b1 <= 70)) {
        b1 -= 55;
      } else if ((b1 >= 48) && (b1 <= 57)) {
        b1 -= 48;
      }
      if ((b2 >= 97) && (b2 <= 102)) {
        b2 -= 87;
      } else if ((b2 >= 65) && (b2 <= 70)) {
        b2 -= 55;
      } else if ((b2 >= 48) && (b2 <= 57)) {
        b2 -= 48;
      }
      iaddr += (b1 * 16 + b2);
    }
    return address(iaddr);
  }
}