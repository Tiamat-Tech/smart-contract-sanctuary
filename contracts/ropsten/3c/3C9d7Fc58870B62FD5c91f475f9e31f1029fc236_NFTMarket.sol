// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarket is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    uint256 feePercent = 10;
    address[] private whitelistedContracts;

    constructor(address _whitelistedContract) Ownable() {
        whitelistedContracts.push(_whitelistedContract);
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable buyer;
        uint256 startPrice;
        uint256 endPrice;
        uint8 duration;
        uint256 createdAt;
        bool onSale;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 startPrice,
        uint256 endPrice,
        uint8 duration,
        uint256 createdAt
    );

    event MarketItemSold(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price,
        uint256 createdAt
    );

    event MarketItemCanceled(uint256 indexed itemId);

    function addToWhitelist(address[] calldata _contracts) public onlyOwner {
        for (uint256 i = 0; i < _contracts.length; i++) {
            whitelistedContracts.push(_contracts[i]);
        }
    }

    function isWhitelisted(address _contract) public view returns (bool) {
        for (uint256 i = 0; i < whitelistedContracts.length; i++) {
            if (whitelistedContracts[i] == _contract) {
                return true;
            }
        }
        return false;
    }

    /* Places an item for sale on the marketplace */
    function createMarketItem(
        address nftContractAddress,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endPrice,
        uint8 duration
    ) public {
        IERC721 nft = IERC721(nftContractAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Is not an NFT owner");
        require(nft.getApproved(tokenId) == address(this), "Contract is not approved as an operator");
        require(isWhitelisted(nftContractAddress), "Contract is not whitelisted");

        nft.transferFrom(msg.sender, address(this), tokenId);

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContractAddress,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            startPrice,
            endPrice,
            duration,
            block.timestamp,
            true
        );

        emit MarketItemCreated(
            itemId,
            nftContractAddress,
            tokenId,
            msg.sender,
            startPrice,
            endPrice,
            duration,
            block.timestamp
        );
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(uint256 itemId)
        public
        payable
        nonReentrant
    {
        MarketItem storage item = idToMarketItem[itemId];
        require(item.onSale, "Is not on sale");
        require(
            msg.value >= getItemPrice(itemId),
            "Please submit the asking price in order to complete the purchase"
        );
        
        IERC721 nft = IERC721(item.nftContract);
        nft.transferFrom(address(this), msg.sender, item.tokenId);
        
        item.seller.transfer(msg.value.sub(calculateFee(msg.value)));
        
        item.buyer = payable(msg.sender);
        item.onSale = false;
        _itemsSold.increment();

        emit MarketItemSold(
            itemId,
            item.nftContract,
            item.tokenId,
            item.seller,
            msg.sender,
            msg.value,
            block.timestamp
        );
    }
    
    /* Removes the sale of a marketplace item */
    function cancelMarketSale(uint256 itemId) public
    {
        MarketItem storage item = idToMarketItem[itemId];
        require(item.onSale, "Is not on sale");
        require(item.seller == msg.sender, "You are not an NFT owner");
        
        IERC721 nft = IERC721(item.nftContract);
        nft.transferFrom(address(this), item.seller, item.tokenId);

        idToMarketItem[itemId].onSale = false;
        emit MarketItemCanceled(itemId);
    }

    function calculateFee(uint256 val) private view returns(uint256) {
        return feePercent.div(100).mul(val);
    }

    /* Returns all unsold market items */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 1; i <= itemCount; i++) {
            if (idToMarketItem[i].onSale) {
                uint256 currentId = i;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user is selling */
    function fetchUserItems(address userAddress) public view returns (MarketItem[] memory) {
        uint256 currentIndex = 0;
        MarketItem[] memory items;

        for (uint256 i = 1; i <= _itemIds.current(); i++) {
            if (idToMarketItem[i].seller == userAddress) {
                uint256 currentId = i;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        
        return items;
    }

    function withdraw() public payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
    
    function getItemPrice(uint256 itemId) public view returns(uint256) {
        MarketItem memory item = idToMarketItem[itemId];
        if (!item.onSale) {
            return 0;
        }
        
        if (block.timestamp >= item.duration) {
            return item.endPrice;
        }

        uint256 diffHours = (block.timestamp.sub(item.createdAt)).div(3600);
        uint256 priceChangePerHour = item.startPrice.sub(item.endPrice).div(item.duration);
        uint256 discount = diffHours.mul(priceChangePerHour);
        uint256 result = item.startPrice.sub(discount);
        
        return result;
    }
}