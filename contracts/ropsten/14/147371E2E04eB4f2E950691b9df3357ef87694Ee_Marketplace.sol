// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Marketplace is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using Counters for Counters.Counter;

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
    }
    event MarketItemCreated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId, address seller, address owner, uint256 price);
    event MarketSaleCreated(uint256 indexed itemId, address indexed nftContract, uint256 indexed tokenId, address seller, address owner, uint256 price);

    // ================ WARNING ==================
    // ===== THIS CONTRACT IS INITIALIZABLE ======
    // === STORAGE VARIABLES ARE DECLARED BELOW ==
    // REMOVAL OR REORDER OF VARIABLES WILL RESULT
    // ========= IN STORAGE CORRUPTION ===========

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    address payable feeCollector;
    uint256 listingPrice; // by default no fee
    mapping(uint256 => MarketItem) private idToMarketItem;

    // ======= STORAGE DECLARATION END ============

    function initialize(address payable _feeCollector, uint256 _listingPrice) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();

        feeCollector = _feeCollector;
        listingPrice = _listingPrice;
    }

    /**
     * @dev Getter function for idToMarketItem
     * @param marketItemId: id
     */
    function getMarketItem(uint256 marketItemId) external view returns (MarketItem memory) {
        return idToMarketItem[marketItemId];
    }

    /**
     * @dev Creates new market item. Marketplace should be already approved to transfer {tokenId}
     * @param nftContract: nftContract address
     * @param tokenId: tokenId
     * @param price: price
     */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice, "Price must be equal to listing price");

        uint256 itemId = _itemIds.current();
        idToMarketItem[itemId] = MarketItem(itemId, nftContract, tokenId, payable(msg.sender), payable(address(0)), price);

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        emit MarketItemCreated(itemId, nftContract, tokenId, msg.sender, address(0), price);
        _itemIds.increment();
    }

    /**
     * @dev Creates market sale. After successful sale, listing price will be sent back to owner wallet
     * @param nftContract: nftContract address
     * @param itemId: tokenId
     */
    function createMarketSale(address nftContract, uint256 itemId) external payable nonReentrant {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");

        // seller could be contract. So recommended to use call here
        (bool sent, ) = idToMarketItem[itemId].seller.call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[itemId].owner = payable(msg.sender);
        emit MarketItemCreated(itemId, nftContract, tokenId, idToMarketItem[itemId].seller, idToMarketItem[itemId].owner, price);
        _itemsSold.increment();
    }

    /**
     * @dev Disburses the fee collected to feeCollector address. Owner function
     * @param amount: Fee amount to withdraw
     */
    function disburseFee(uint256 amount) external onlyOwner {
        require(feeCollector != address(0), "No fee collector");
        require(amount <= address(this).balance, "Not enough fee amount");

        (bool sent, ) = feeCollector.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    /**
     * @dev Sets new fee collector address. Owner function
     * @param _feeCollector: new address
     */
    function setFeeCollector(address payable _feeCollector) external onlyOwner {
        require(_feeCollector != payable(0), "Invalid fee collector address");
        feeCollector = _feeCollector;
    }

    /**
     * @dev Sets new listing price. Owner function
     * @param _listingPrice: new fee
     */
    function setListingPrice(uint256 _listingPrice) external onlyOwner {
        listingPrice = _listingPrice;
    }

    /**
     * @dev Returns current available market items
     */
    function fetchMarketItems() external view returns (MarketItem[] memory) {
        return _fetchNFTsFor(address(0));
    }

    /**
     * @dev Returns market items for msg.sender
     */
    function fetchMyNFTs() external view returns (MarketItem[] memory) {
        return _fetchNFTsFor(msg.sender);
    }

    /**
     * @dev Returns available market items that _owner address has
     * @param _owner: Owner address
     */
    function _fetchNFTsFor(address _owner) internal view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        if (_owner == address(0)) {
            itemCount = totalItemCount - _itemsSold.current();
        } else {
            for (uint256 i = 0; i < totalItemCount; i++) {
                if (idToMarketItem[i].owner == _owner) {
                    itemCount++;
                }
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i].owner == _owner) {
                items[currentIndex] = idToMarketItem[i];
                currentIndex++;
            }
        }

        return items;
    }
}