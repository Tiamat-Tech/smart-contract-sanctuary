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

    Counters.Counter private _itemIds;
    EnumerableSet.UintSet private _activeIds;

    mapping(address => mapping(uint256 => uint256)) private _usersListings;
    mapping(uint256 => uint256) private _usersListingsIndex;
    mapping(address => Counters.Counter) private _usersTotalListings;
    mapping(uint256 => MarketItem) private _marketItems;

    address payable private _feesAddress;
    uint256 private _saleFeePercentage;
    
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

    constructor(address feesAddress, uint256 saleFeePercentage) {
        _saleFeePercentage = saleFeePercentage;
        _feesAddress = payable(feesAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

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

        _addListingToUserEnumeration(msg.sender, itemId);

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

        _removeListingFromUserEnumeration(msg.sender, itemId);

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

        _removeListingFromUserEnumeration(_marketItems[itemId].seller, itemId);
        _addListingToUserEnumeration(msg.sender, itemId);

        emit ItemSold(itemId, nftContract, tokenId, _marketItems[itemId].seller, msg.sender, price);
    }

    // Allows controller to set new sales fee percentage
    function setSaleFeesPercentage(uint256 newSaleFeesPercentage) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "NativeToken721Market: Must be admin");
        _saleFeePercentage = newSaleFeesPercentage;
    }
    
    function totalListings() public view returns (uint256) {
        return _itemIds.current();
    }
    
    function userTotalListings(address user) public view returns(uint256) {
        return _usersTotalListings[user].current();
    }

    function listingOfUserByIndex(address user, uint256 index) public view  returns (uint256) {
        require(index < _usersTotalListings[user].current(), "NativeToken721Market: owner index out of bounds");
        return _usersListings[user][index];
    }

    function listingByIndex(uint256 index) public view returns (MarketItem memory) {
        require(index <= _itemIds.current(), "NativeToken721Market: global index out of bounds");
        return _marketItems[index];
    }

    function activeListings() public view returns (MarketItem[] memory) {
        uint256 totalActive = _activeIds.length();
        MarketItem[] memory items = new MarketItem[](totalActive);

        for (uint256 i = 0; i < totalActive; i++) {
            MarketItem storage currentItem = _marketItems[_activeIds.at(i)];
            items[i] = currentItem;
        }
        return items;
    }

    function usersListings(address user) public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _usersTotalListings[user].current();
        
        MarketItem[] memory items = new MarketItem[](totalItemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            uint256 targetId = listingOfUserByIndex(user, i);
            
            MarketItem storage currentItem = _marketItems[targetId];
            items[i] = currentItem;
        }
        return items;
    }


    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addListingToUserEnumeration(address to, uint256 tokenId) private {
        _usersListings[to][_usersTotalListings[to].current()] = tokenId;
        _usersListingsIndex[tokenId] = _usersTotalListings[to].current();
        _usersTotalListings[to].increment();
    }

     /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeListingFromUserEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).
        uint256 lastTokenIndex = _usersTotalListings[from].current() - 1;
        _usersTotalListings[from].decrement();
        uint256 tokenIndex = _usersListingsIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _usersListings[from][lastTokenIndex];

            _usersListings[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _usersListingsIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _usersListingsIndex[tokenId];
        delete _usersListings[from][lastTokenIndex];
    }

}