// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

/// @author Nawab Khairuzzaman Mohammad Kibria
/// @title A NFT marketplace

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarket is ReentrancyGuard {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _itemIds;
  Counters.Counter private _itemsSold;

  address payable owner; // Contract owner Address

  uint256 listingPrice; // Listing Price

  /// Store   `owner`
  /// @dev store the smart contract deployer address in the state variable `owner`
  constructor() {
    owner = payable(msg.sender);
  }

  struct MarketItem {
    uint256 itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
  }

  mapping(uint256 => MarketItem) private idToMarketItem;

  event ItemListed(
    uint256 indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price
  );

  event ItemSold(
    uint256 indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price
  );

  /// Get market Data by `marketItemId`
  /// @param marketItemId for find the market data
  /// @dev retrieves the marketItem data of given itemId
  /// @return a single market item
  function getMarketItem(uint256 marketItemId)
    public
    view
    returns (MarketItem memory)
  {
    return idToMarketItem[marketItemId];
  }

  /// List any NFT to the market for fixed price
  /// @param nftContract, @param tokenId, @param price for list on the market
  /// @dev list any NFT on the market

  function listOnMarket(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {
    require(price > 0, "Price must be at least 1 wei");
    _itemIds.increment();
    uint256 itemId = _itemIds.current();
    payable(owner).transfer(listingPrice);
    idToMarketItem[itemId] = MarketItem(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),
      payable(address(0)),
      price
    );

    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

    emit ItemListed(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),
      price
    );
  }

  /// Buy an NFT from Marketplace
  /// @param nftContract, @param itemId for by a specific NFT
  /// @dev buy any NFT from the market
  /// @notice Buyer must pay the asking price

  function buy(address nftContract, uint256 itemId)
    public
    payable
    nonReentrant
  {
    uint256 price = idToMarketItem[itemId].price;
    uint256 tokenId = idToMarketItem[itemId].tokenId;
    require(
      msg.value == price,
      "Please submit the asking price in order to complete the purchase"
    );
    require(idToMarketItem[itemId].owner != address(0), "Already Sold");
    idToMarketItem[itemId].seller.transfer(msg.value);
    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    idToMarketItem[itemId].owner = payable(msg.sender);
    _itemsSold.increment();
  }

  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }

  function setListingPrice(uint256 _listingPrice) public {
    require(msg.sender == owner, "You are not owner");
    listingPrice = _listingPrice;
  }

  // /// Get all unsold market Items
  // /// @return MarketItem[] : All unsold market items

  // function fetchMarketItems() public view returns (MarketItem[] memory) {
  //     uint itemCount = _itemIds.current();
  //     uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
  //     uint currentIndex = 0;

  //     MarketItem[] memory items = new MarketItem[](unsoldItemCount);
  //     for (uint i = 0; i < itemCount; i++) {
  //       if (idToMarketItem[i + 1].owner == address(0)) {
  //         uint currentId = idToMarketItem[i + 1].itemId;
  //         MarketItem storage currentItem = idToMarketItem[currentId];
  //         items[currentIndex] = currentItem;
  //         currentIndex += 1;
  //       }
  //     }
  //     return items;
  // }

  // /// Get all bought NFTs of the caller
  // /// @return MarketItem[] : All bought NFTs of the caller

  // function fetchMyNFTs() public view returns (MarketItem[] memory) {
  //     uint totalItemCount = _itemIds.current();
  //     uint itemCount = 0;
  //     uint currentIndex = 0;

  //     for (uint i = 0; i < totalItemCount; i++) {
  //       if (idToMarketItem[i + 1].owner == msg.sender) {
  //         itemCount += 1;
  //       }
  //     }

  //     MarketItem[] memory items = new MarketItem[](itemCount);
  //     for (uint i = 0; i < totalItemCount; i++) {
  //       if (idToMarketItem[i + 1].owner == msg.sender) {
  //         uint currentId = idToMarketItem[i + 1].itemId;
  //         MarketItem storage currentItem = idToMarketItem[currentId];
  //         items[currentIndex] = currentItem;
  //         currentIndex += 1;
  //       }
  //     }
  //     return items;
  // }

  // /// Get all sold and unsold NFTs of the caller
  // /// @return MarketItem[] : All sold and unsold NFTs of the caller
  // function fetchMyListedNFT() public view returns (MarketItem[] memory) {
  //     uint totalItemCount = _itemIds.current();
  //     uint itemCount = 0;
  //     uint currentIndex = 0;

  //     for (uint i = 0; i < totalItemCount; i++) {
  //       if (idToMarketItem[i + 1].seller == msg.sender) {
  //         itemCount += 1;
  //       }
  //     }

  //     MarketItem[] memory items = new MarketItem[](itemCount);

  //     for (uint i = 0; i < totalItemCount; i++) {
  //       if (idToMarketItem[i + 1].seller == msg.sender) {
  //         uint currentId = idToMarketItem[i + 1].itemId;
  //         MarketItem storage currentItem = idToMarketItem[currentId];
  //         items[currentIndex] = currentItem;
  //         currentIndex += 1;
  //       }
  //     }
  //     return items;

  // }
}