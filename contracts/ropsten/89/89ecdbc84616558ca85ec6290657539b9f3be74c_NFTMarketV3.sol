// contracts/Market.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./TunaToken.sol";

import "hardhat/console.sol";

// NFTMarketV2 payment by custom ERC20 token: TunaToken
contract NFTMarketV3 is ReentrancyGuardUpgradeable {
  using Counters for Counters.Counter;
  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;

  address payable owner;
  uint256 listingPrice;

  function initialize() internal initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
    owner = payable(msg.sender);
    listingPrice = 0.025 ether;
  }

  struct MarketItem {
    uint itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
  }

  mapping(uint256 => MarketItem) private idToMarketItem;

  event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
  );

  event MarketItemSold (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price
  );

  address tunaTokenAddress;
  bool isChangeOwnerBecauseMistake;
  bool isInitTunaToken;

  function initTunaTokenAddress(address _tunaTokenAddress) public {
      require(isInitTunaToken == false, "Only init once time");
      require(msg.sender == owner, "Only owner can set the address");
      tunaTokenAddress = _tunaTokenAddress;
      isInitTunaToken = true;
  }

  function changeOwner(address _owner) public {
    require(isChangeOwnerBecauseMistake == false, "Only change one time because mistake deploy before");
    owner = payable(_owner);
    isChangeOwnerBecauseMistake = true;
  }

  /* Returns the listing price of the contract */
  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }

  /* Returns the listing price of the contract */
  function getOwner() public view returns (address) {
    return owner;
  }

  /* Returns the listing price of the contract */
  function getTunaTokenAddress() public view returns (address) {
    return tunaTokenAddress;
  }

  /* Places an item for sale on the marketplace */
  function createMarketItem(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {
    require(price > 0, "Price must be at least 1 TUNA");
    require(msg.value == listingPrice, "Price must be equal to listing price");

    _itemIds.increment();
    uint256 itemId = _itemIds.current();

    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price,
      false
    );

    IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

    emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price,
      false
    );
  }

  /* Creates the sale of a marketplace item */
  /* Transfers ownership of the item, as well as funds between parties */
  function createMarketSale(
    address nftContract,
    uint256 itemId,
    uint256 payableAmount
    ) public nonReentrant {
    uint price = idToMarketItem[itemId].price;
    uint tokenId = idToMarketItem[itemId].tokenId;
    require(payableAmount == price, "Please submit the asking price in order to complete the purchase");

    uint256 allowance = IERC20(tunaTokenAddress).allowance(msg.sender, address(this));
    require(allowance >= payableAmount, "Check to token allowance to make sure you allow enough to buy");
    require(IERC20(tunaTokenAddress).balanceOf(msg.sender) >= payableAmount, "Don't have enough Tuna to pay");

    // send token to seller
    IERC20(tunaTokenAddress).transferFrom(msg.sender, idToMarketItem[itemId].seller, price);
  
    // send nft to buyer
    IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
  
    // update market item info
    idToMarketItem[itemId].owner = payable(msg.sender);
    idToMarketItem[itemId].sold = true;
    _itemsSold.increment();

    // send listing price to owner of NFTMarket contract
    payable(owner).transfer(listingPrice);

    emit MarketItemSold(
      itemId,
      nftContract,
      tokenId,
      idToMarketItem[itemId].seller,
      idToMarketItem[itemId].owner,
      price
    );
  }

  /* Returns all unsold market items */
  function fetchMarketItems() public view returns (MarketItem[] memory) {
    uint itemCount = _itemIds.current();
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    uint currentIndex = 0;

    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    for (uint i = 0; i < itemCount; i++) {
      if (idToMarketItem[i + 1].owner == address(0)) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items that a user has purchased */
  function fetchMyNFTs() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].owner == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  /* Returns only items a user has created */
  function fetchItemsCreated() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;

    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        itemCount += 1;
      }
    }

    MarketItem[] memory items = new MarketItem[](itemCount);
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

  function onERC721Received(address, address, uint256, bytes calldata) external returns(bytes4) {
    return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
  }
}