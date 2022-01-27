// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// !!! WARNING: TEST CONTRACT !!!
contract NativeToken721Market is ReentrancyGuard, AccessControlEnumerable {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    enum MarketState{ INACTIVE, ACTIVE, SOLD, CANCELLED }

    Counters.Counter private _itemIds;
    EnumerableSet.UintSet _activeIds;

    address payable private _feesAddress;
    uint256 private _saleFeePercentage;

    constructor(address feesAddress, uint256 saleFeePercentage) {
        _saleFeePercentage = saleFeePercentage;
        _feesAddress = payable(feesAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        MarketState state;
        uint256 listedPercentage;
    }

    mapping(uint256 => MarketItem) private _marketItems;

    event ItemListed (
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 price
    );

    event ItemSold (
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price
    );

    event ItemCancelled (
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller
    );

    /* Returns the percentage taken from sales  */
    function getSaleFeePercentage() public view returns (uint256) {
        return _saleFeePercentage;
    }

    /* Places an item for sale on the marketplace */
    function listItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public nonReentrant {
        require(price > 0, "NativeToken721Market: Price must be at least 1 wei");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();
        _activeIds.add(itemId);

        _marketItems[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            MarketState.ACTIVE,
            _saleFeePercentage
        );

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit ItemListed(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            price
        );
    }

     /* Places an item for sale on the marketplace */
    function cancelListing(
        uint256 itemId
    ) public nonReentrant {
        require(_msgSender() == _marketItems[itemId].seller, "NativeToken721Market: Only seller can cancel");
        require(_marketItems[itemId].state == MarketState.ACTIVE, "NativeToken721Market: Only active sales can be cancelled");

        IERC721(_marketItems[itemId].nftContract).transferFrom(address(this), _msgSender(), _marketItems[itemId].tokenId);
        _marketItems[itemId].state = MarketState.CANCELLED;
        _activeIds.remove(itemId);

        emit ItemCancelled(itemId, _marketItems[itemId].nftContract, _marketItems[itemId].tokenId, _msgSender());
    }

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function purchaseItem(
        address nftContract,
        uint256 itemId
    ) public payable nonReentrant {
        uint256 price = _marketItems[itemId].price;
        uint256 tokenId = _marketItems[itemId].tokenId;
        require(msg.value == price, "NativeToken721Market: Please submit the asking price in order to complete the purchase");
        require(_marketItems[itemId].state == MarketState.ACTIVE, "NativeToken721Market: Only active sales can be purchased");
        
        // Check for safemath
        uint256 feesPortion = msg.value / _marketItems[itemId].listedPercentage;
    
        payable(_marketItems[itemId].seller).transfer(msg.value - feesPortion);
        payable(_feesAddress).transfer(feesPortion);

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        _marketItems[itemId].owner = payable(msg.sender);
        _marketItems[itemId].state = MarketState.SOLD;
        _activeIds.remove(itemId);

        emit ItemSold(itemId, nftContract, tokenId, _marketItems[itemId].seller, msg.sender, price);
    }

    /* Returns all unsold market items */
    function fetchItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](_activeIds.length());
        for (uint256 i = 0; i < itemCount; i++) {
            if (_marketItems[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = _marketItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_marketItems[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_marketItems[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = _marketItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_marketItems[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (_marketItems[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = _marketItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Fetch sale by index
    function fetchItemByIndex(uint256 itemId) public view returns (MarketItem memory) {
        return _marketItems[itemId];
    }

    // Allows controller to set new sales fee percentage
    function setSaleFeesPercentage(uint256 newSaleFeesPercentage) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "NativeToken721Market: Must be admin");
        _saleFeePercentage = newSaleFeesPercentage;
    }
}