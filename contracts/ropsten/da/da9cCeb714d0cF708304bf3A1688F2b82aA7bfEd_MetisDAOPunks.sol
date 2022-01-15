pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MetisDAOPunks is ERC721Enumerable, Ownable {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;

  uint256 public constant MAX_SUPPLY = 10000;
  uint256 public constant PRICE = 0.1 ether;
  uint256 public constant MAX_PER_MINT = 21;

  string public baseTokenURI;
  bool public saleActive;

  constructor() ERC721("MetisDAO Punks", "PUNKS") {}

  function reserveNFTs() public onlyOwner {
    uint256 totalMinted = _tokenIds.current();

    require(
      totalMinted.add(100) < MAX_SUPPLY,
      "Not enough NFTs left to reserve"
    );

    for (uint256 i = 0; i < 100; i++) {
      _mintSingleNFT();
    }
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function setBaseURI(string memory _baseTokenURI) public onlyOwner {
    baseTokenURI = _baseTokenURI;
  }

  function mintNFTs(uint256 _count) public payable {
    uint256 totalMinted = _tokenIds.current();
    uint256 counter;

    if (_count == 10) {
      counter = _count + 2;
    } else if (_count == 17) {
      counter = _count + 4;
    } else {
      counter = _count;
    }

    require(saleActive, "Maybe later");
    require(totalMinted.add(counter) <= MAX_SUPPLY, "Not enough NFTs left!");
    require(_count > 0 && _count <= MAX_PER_MINT, "Wrong number");

    require(msg.value >= PRICE.mul(_count), "Need more Metis");

    for (uint256 i = 0; i < counter; i++) {
      _mintSingleNFT();
    }
  }

  function _mintSingleNFT() private {
    uint256 newTokenID = _tokenIds.current();
    _safeMint(msg.sender, newTokenID);
    _tokenIds.increment();
  }

  function tokensOfOwner(address _owner)
    external
    view
    returns (uint256[] memory)
  {
    uint256 tokenCount = balanceOf(_owner);
    uint256[] memory tokensId = new uint256[](tokenCount);

    for (uint256 i = 0; i < tokenCount; i++) {
      tokensId[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokensId;
  }

  function withdraw() public onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0, "No ether left to withdraw");

    (bool success, ) = (msg.sender).call{ value: balance }("");
    require(success, "Transfer failed.");
  }

  function flipSale() public onlyOwner {
    saleActive = !saleActive;
  }
}