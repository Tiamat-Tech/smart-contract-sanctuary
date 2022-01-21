//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./opensea/ERC721Tradable.sol";

contract OverHypedPandasSeries1 is ERC721Tradable, ReentrancyGuard {
  using Counters for Counters.Counter;

  uint256 private _launchTimestamp;
  uint256 private _publicSaleTimestamp;

  uint256 private _maxPerWalletAddress = 5;
  
  uint256 private _totalPandasCount = 5000;
  uint256 private _tokenTiersCount = 4; // Excluding Giveaways tier
  uint256 private _whiteListedCount = 0; // Excluding Giveaways tier
  uint256 private _totalSalesCount = 0;

  mapping(address => bool) private _whiteListed;

  mapping(uint256 => uint256) private _tierPrices;
  mapping(uint256 => uint256) private _tierSales;
  mapping(uint256 => uint256) private _tierAmounts;
  mapping(uint256 => uint256) private _tokenTiers;

  constructor(address proxyRegistryAddress, uint256 launchTimestamp, uint256 publicSaleTimestamp)
    ERC721Tradable("OverHyped Panda Series 1", "OHPS1", proxyRegistryAddress) {
    _tierPrices[0] = 1000000000000000000; // 1.0 ETH
    _tierPrices[1] = 750000000000000000; // 0.75 ETH
    _tierPrices[2] = 500000000000000000; // 0.50 ETH
    _tierPrices[3] = 250000000000000000; // 0.25 ETH

    _tierSales[0] = 0;
    _tierSales[1] = 0;
    _tierSales[2] = 0;
    _tierSales[3] = 0;
    _tierSales[4] = 0; // Giveaways

    _tierAmounts[0] = 750;  
    _tierAmounts[1] = 1000; 
    _tierAmounts[2] = 1250; 
    _tierAmounts[3] = 1750; 
    _tierAmounts[4] = 250; // Giveaways

    _launchTimestamp = launchTimestamp;
    _publicSaleTimestamp = publicSaleTimestamp;
  }

  function mintPanda(uint256 tier) public payable {
      require(block.timestamp >= _launchTimestamp && (block.timestamp >= _publicSaleTimestamp || _whiteListed[_msgSender()] == true), "Sale still not open!");
      require(tier < _tokenTiersCount, "Invalid tier");
      require(_totalSalesCount < _totalPandasCount && _tierSales[tier] < _tierAmounts[tier], "Minting exceeded");
      require(msg.value >= _tierPrices[tier], "More ETH required to mint a Panda of this tier");
      require(balanceOf(_msgSender()) + 1 <= _maxPerWalletAddress, "Minting exceeded for wallet");

      uint256 tokenId = _nextTokenId.current();
      _nextTokenId.increment();
      _safeMint(_msgSender(), tokenId);

      _tokenTiers[tokenId] = tier;
      _totalSalesCount += 1;
      _tierSales[tier] += 1;

      emit PandaSeries1Minted(_msgSender(), tokenId, tier);
  }

  function mintGiveaway(address to) external onlyOwner {
    require(block.timestamp >= _launchTimestamp, "Wait for the launch date!");
    require(_totalSalesCount < _totalPandasCount && _tierSales[4] < _tierAmounts[4], "Minting exceeded");

    uint256 tokenId = _nextTokenId.current();

    mintTo(to);

    _tokenTiers[tokenId] = 4; //Giveaway
    _totalSalesCount += 1;
    _tierSales[4] += 1;

    emit PandaSeries1Minted(to, tokenId, 4);
  }

  function addToWhitelist(address[] memory _addresses) external onlyOwner {
      require(_addresses.length > 0, "No addresses");
      for (uint256 i = 0; i < _addresses.length; i++) {
        _whiteListed[_addresses[i]] = true;
        _whiteListedCount += 1;
        emit AddedToWhiteList(_addresses[i]);
      }
  }

  function removeFromWhitelist(address _address) external onlyOwner {
      require(_whiteListed[_address] == true, "Address is not whitelisted");
      _whiteListed[_address] = false;
      _whiteListedCount--;
      emit RemovedFromWhiteList(_address);
    }

  function safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) external {
      _safeTransfer(from, to, tokenId, _data);
  }     

  function safeTransferFrom(address from, address to, uint256 tokenId) public override {
      _safeTransfer(from, to, tokenId, "");
  }    

  function burn(uint256 tokenId) external {
      _burn(tokenId);
  }

  function baseTokenURI() virtual override public pure returns (string memory) {
    return "https://nft.overhyped.io/metadata/series1/";
  }

  function getAvailableByTier(uint256 tier) public virtual view returns(uint256 amount) {
    return _tierAmounts[tier] - _tierSales[tier];
  }

  function getTierOf(uint256 tokenId) public virtual view returns(uint256 tier) {
    return _tokenTiers[tokenId];
  }

  function getTotalSales() public virtual view onlyOwner returns(uint256 total) {
    return _totalSalesCount;
  }

  function getTotalTierSales(uint256 tier) public virtual view onlyOwner returns(uint256 total) {
    return _tierSales[tier];
  }

  function getWhitelistedSaleOpen() public virtual view onlyOwner returns(bool open) {
    return block.timestamp >= _launchTimestamp;
  }

  function getPublicSaleOpen() public virtual view onlyOwner returns(bool open) {
    return block.timestamp >= _publicSaleTimestamp;
  }

  /** Events **/
  event PandaSeries1Minted(address indexed minter, uint256 indexed tokenId, uint256 indexed tier);
  event AddedToWhiteList(address indexed whitelistAddress);
  event RemovedFromWhiteList(address indexed removedAddress);

}