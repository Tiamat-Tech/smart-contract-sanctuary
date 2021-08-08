// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./TalaNFT.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract TalaMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    TalaNFT private _token;
    address payable private _deployer;
    uint256 public listingPrice = 0.025 ether;

    constructor(TalaNFT token) {
        _deployer = payable(msg.sender);
        _token = token;
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private _idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    /* Places an item for sale on the marketplace */
    function createMarketItem(
        string memory tokenURI,
        uint256 price
    ) external payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        uint256 itemId = TalaNFT(_token).createToken(tokenURI);
        TalaNFT(_token).setApprovalForAll(msg.sender, true);
        _itemIds.increment();

        _idToMarketItem[itemId] = MarketItem(
            itemId,
            address(_token),
            payable(msg.sender),
            payable(address(0)),
            price,
            false
        );

        emit MarketItemCreated(
            itemId,
            address(_token),
            msg.sender,
            address(0),
            price,
            false
        );
    }

    /* Update item price and put for re-sale on the marketplace */
    function updateMarketItem(
        uint256 itemId,
        uint256 price
    ) external payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(
            msg.value == listingPrice,
            "Price must be equal to listing price"
        );

        _idToMarketItem[itemId].price = price;				// update sale price
        _idToMarketItem[itemId].owner = payable(address(0)); // update owner (market)
		_idToMarketItem[itemId].sold  = false;
		_itemsSold.decrement();
        TalaNFT(_token).transferFrom(msg.sender, address(this), itemId);
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(uint256 itemId)
        external
        payable
        nonReentrant
    {
        uint256 price = _idToMarketItem[itemId].price;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );

        _idToMarketItem[itemId].seller.transfer(msg.value);
        _idToMarketItem[itemId].owner = payable(msg.sender);
        _idToMarketItem[itemId].sold  = true;
        _itemsSold.increment();
        payable(_deployer).transfer(listingPrice);
        TalaNFT(_token).transferFrom(address(this), msg.sender, itemId);
    }

    /* Returns all unsold market items */
    function fetchMarketItems() external view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (_idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = _idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() external view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = _idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has created */
    function fetchItemsCreated() external view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = _idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}