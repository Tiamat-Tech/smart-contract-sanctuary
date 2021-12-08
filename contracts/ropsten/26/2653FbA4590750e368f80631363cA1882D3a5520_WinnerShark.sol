// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';

contract WinnerShark is ERC721, ERC721Enumerable, Ownable {
  using Strings for uint256;
  bool public _isSaleActive = false;
  bool public _isAuctionActive = false;

  // Constants
  uint256 constant public MAX_SUPPLY = 888;

  uint256 public mintPrice = 0.24 ether;
  uint256 public tierSupply = 260;
  uint256 public maxBalance = 2;
  uint256 public maxMint = 2;

  uint256 public auctionStartTime;
  uint256 public auctionTimeStep;
  uint256 public auctionStartPrice;
  uint256 public auctionEndPrice;
  uint256 public auctionPriceStep;
  uint256 public auctionStepNumber;

  string private _baseURIExtended;

  event TokenMinted(uint256 supply);
  event SaleStarted();
  event SalePaused();
  event AuctionStarted();
  event AuctionPaused();

  constructor() ERC721('Winner Shark', 'WS') {}

  function startSale() public onlyOwner {
    _isSaleActive = true;
    emit SaleStarted();
  }

  function pauseSale() public onlyOwner {
    _isSaleActive = false;
    emit SalePaused();
  }

  function startAuction() public onlyOwner {
    _isAuctionActive = true;
    emit AuctionStarted();
  }

  function pauseAuction() public onlyOwner {
    _isAuctionActive = false;
    emit AuctionPaused();
  }

  function setMintPrice(uint256 _mintPrice) public onlyOwner {
    mintPrice = _mintPrice;
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

  function withdraw(address to) public onlyOwner {
    uint256 balance = address(this).balance;
    payable(to).transfer(balance);
  }

  function preserveMint(uint numWinnerSharks, address to) public onlyOwner {
    require(totalSupply() + numWinnerSharks <= tierSupply, 'Preserve mint would exceed tier supply');
    require(totalSupply() + numWinnerSharks <= MAX_SUPPLY, 'Preserve mint would exceed max supply');
    _mintWinnerShark(numWinnerSharks, to);
    emit TokenMinted(totalSupply());
  }

  function getTotalSupply() public view returns (uint256) {
    return totalSupply();
  }

  function getWinnerSharkByOwner(address _owner) public view returns (uint256[] memory) {
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

  function mintWinnerShark(uint numWinnerSharks) public payable {
    require(_isSaleActive, 'Sale must be active to mint WinnerSharks');
    require(totalSupply() + numWinnerSharks <= tierSupply, 'Sale would exceed tier supply');
    require(totalSupply() + numWinnerSharks <= MAX_SUPPLY, 'Sale would exceed max supply');
    require(balanceOf(msg.sender) + numWinnerSharks <= maxBalance, 'Sale would exceed max balance');
    require(numWinnerSharks <= maxMint, 'Sale would exceed max mint');
    require(numWinnerSharks * mintPrice <= msg.value, 'Not enough ether sent');
    _mintWinnerShark(numWinnerSharks, msg.sender);
    emit TokenMinted(totalSupply());
  }

  function auctionMintWinnerShark(uint numWinnerSharks) public payable {
    require(_isAuctionActive, 'Auction must be active to mint WinnerSharks');
    require(block.timestamp >= auctionStartTime, 'Auction not start');
    require(totalSupply() + numWinnerSharks <= tierSupply, 'Auction would exceed tier supply');
    require(totalSupply() + numWinnerSharks <= MAX_SUPPLY, 'Auction would exceed max supply');
    require(balanceOf(msg.sender) + numWinnerSharks <= maxBalance, 'Auction would exceed max balance');
    require(numWinnerSharks <= maxMint, 'Auction would exceed max mint');
    require(numWinnerSharks * getAuctionPrice() <= msg.value, 'Not enough ether sent');
    _mintWinnerShark(numWinnerSharks, msg.sender);
    emit TokenMinted(totalSupply());
  }

  function _mintWinnerShark(uint256 numWinnerSharks, address recipient) internal {
    uint256 supply = totalSupply();
    for (uint256 i = 0; i < numWinnerSharks; i++) {
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