// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract Boost is ERC721, ERC721Enumerable, Ownable {
  using Strings for uint256;
  bool public _isWhiteListSaleActive = false;
  bool public _isSaleActive = false;
  bool public _isAuctionActive = false;

  // Constants
  uint256 constant public MAX_SUPPLY = 999;

  uint256 public mintPrice = 0.9 ether;
  uint256 public whiteListPrice = 0.9 ether;
  uint256 public fomoDogWhiteListPrice = 0.8 ether;
  uint256 public tierSupply = 268;
  uint256 public maxBalance = 1;
  uint256 public maxMint = 1;

  uint256 public auctionStartTime;
  uint256 public auctionTimeStep;
  uint256 public auctionStartPrice;
  uint256 public auctionEndPrice;
  uint256 public auctionPriceStep;
  uint256 public auctionStepNumber;

  string private _baseURIExtended;

  mapping(address => bool) public whiteList;
  mapping(address => bool) public fomoDogWhiteList;

  event TokenMinted(uint256 supply);

  constructor() ERC721('Boost', 'BO') {}

  function flipWhiteListSaleActive() public onlyOwner {
    _isWhiteListSaleActive = !_isWhiteListSaleActive;
  }

  function filpSaleActive() public onlyOwner {
    _isSaleActive = !_isSaleActive;
  }

  function flipAuctionActive() public onlyOwner {
    _isAuctionActive = !_isAuctionActive;
  }

  function setMintPrice(uint256 _mintPrice) public onlyOwner {
    mintPrice = _mintPrice;
  }

  function setWhiteListPrice(uint256 _whiteListPrice) public onlyOwner {
    whiteListPrice = _whiteListPrice;
  }

  function setFomoDogWhiteListPrice(uint256 _fomoDogWhiteListPrice) public onlyOwner {
    fomoDogWhiteListPrice = _fomoDogWhiteListPrice;
  }

  function setTierSupply(uint256 _tierSupply) public onlyOwner {
    tierSupply = _tierSupply;
  }

  function setMaxBalance(uint256 _maxBalance) public onlyOwner {
    maxBalance = _maxBalance;
  }

  function setMaxMint(uint256 _maxMint) public onlyOwner {
    maxMint = _maxMint;
  }

  function setAuction(uint256 _auctionStartTime, uint256 _auctionTimeStep, uint256 _auctionStartPrice, uint256 _auctionEndPrice, uint256 _auctionPriceStep, uint256 _auctionStepNumber) public onlyOwner {
    auctionStartTime = _auctionStartTime;
    auctionTimeStep = _auctionTimeStep;
    auctionStartPrice = _auctionStartPrice;
    auctionEndPrice = _auctionEndPrice;
    auctionPriceStep = _auctionPriceStep;
    auctionStepNumber = _auctionStepNumber;
  }

  function setWhiteList(address[] memory _whiteList) public onlyOwner {
    for(uint i = 0; i < _whiteList.length; i++) {
      whiteList[_whiteList[i]] = true;
    }
  }

  function setFomoDogWhiteList(address[] memory _fomoDogWhiteList) public onlyOwner {
    for(uint i = 0; i < _fomoDogWhiteList.length; i++) {
      fomoDogWhiteList[_fomoDogWhiteList[i]] = true;
    }
  }

  function withdraw(address to) public onlyOwner {
    uint256 balance = address(this).balance;
    payable(to).transfer(balance);
  }

  function preserveMint(uint numboosts, address to) public onlyOwner {
    require(totalSupply() + numboosts <= tierSupply, 'Preserve mint would exceed tier supply');
    require(totalSupply() + numboosts <= MAX_SUPPLY, 'Preserve mint would exceed max supply');
    _mintboost(numboosts, to);
    emit TokenMinted(totalSupply());
  }

  function getTotalSupply() public view returns (uint256) {
    return totalSupply();
  }

  function getboostByOwner(address _owner) public view returns (uint256[] memory) {
    uint256 tokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](tokenCount);
    for (uint256 i; i < tokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function getAuctionPrice() public view returns (uint256) {
    if (!_isAuctionActive) {
      return 0;
    }
    if (block.timestamp < auctionStartTime) {
      return auctionStartPrice;
    }
    uint256 step = (block.timestamp - auctionStartTime) / auctionTimeStep;
    if (step > auctionStepNumber) {
      step = auctionStepNumber;
    }
    return 
      auctionStartPrice > step * auctionPriceStep
        ? auctionStartPrice - step * auctionPriceStep
        : auctionEndPrice;
  }

  function mintboosts(uint numboosts) public payable {
    require(_isSaleActive, 'Sale must be active to mint boosts');
    require(totalSupply() + numboosts <= tierSupply, 'Sale would exceed tier supply');
    require(totalSupply() + numboosts <= MAX_SUPPLY, 'Sale would exceed max supply');
    require(balanceOf(msg.sender) + numboosts <= maxBalance, 'Sale would exceed max balance');
    require(numboosts <= maxMint, 'Sale would exceed max mint');
    require(numboosts * mintPrice <= msg.value, 'Not enough ether sent');
    _mintboost(numboosts, msg.sender);
    emit TokenMinted(totalSupply());
  }

  function auctionMintboost(uint numboosts) public payable {
    require(_isAuctionActive, 'Auction must be active to mint boosts');
    require(block.timestamp >= auctionStartTime, 'Auction not start');
    require(totalSupply() + numboosts <= tierSupply, 'Auction would exceed tier supply');
    require(totalSupply() + numboosts <= MAX_SUPPLY, 'Auction would exceed max supply');
    require(balanceOf(msg.sender) + numboosts <= maxBalance, 'Auction would exceed max balance');
    require(numboosts <= maxMint, 'Auction would exceed max mint');
    require(numboosts * getAuctionPrice() <= msg.value, 'Not enough ether sent');
    _mintboost(numboosts, msg.sender);
    emit TokenMinted(totalSupply());
  }

  function _mintboost(uint256 numboosts, address recipient) internal {
    uint256 supply = totalSupply();
    for (uint256 i = 0; i < numboosts; i++) {
      _safeMint(recipient, supply + i);
    }
  }

  function setBaseURI(string memory baseURI_) external onlyOwner {
    _baseURIExtended = baseURI_;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return _baseURIExtended;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), 'ERC721Metadata: URI query for nonexistent token');
    return string(abi.encodePacked(_baseURI(), tokenId.toString()));
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
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