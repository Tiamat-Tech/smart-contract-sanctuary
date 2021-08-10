// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract NFTProject is ERC721, Ownable, Pausable {
    using SafeMath for uint256;
    using Address for address;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct ItemOwners {
        address owner;
        uint256 purchasedPrice;
        uint256 timestamp;
    }

    struct Item {
        address payable owner;
        string collection;
        uint256 price;
        bool openForSale;
        bool openForOffer;
        uint256 minimumAllowedBid;
        bool paused;
        string itemMetaData;
        Counters.Counter ownershipTransferCount;
        mapping(uint256 => ItemOwners) ownershipTransferTransaction;
    }

    address payable private platformWallet;

    uint256 public creatorRoyality;
    uint256 public platformRoyality;

    mapping(uint256 => Item) public itemsOnProject;

    event PurchasedItem(
        uint256 itemID,
        address buyerAddress,
        uint256 purchasedPrice,
        address newOwnerAddress
    );

    event ownershipTransferredOfItem(
        uint256 itemID,
        uint256 transactionID,
        address buyerAddress,
        uint256 purchasedPrice,
        address newOwnerAddress
    );

    event UpdatedPlatformWalletAddress(
        address newAddress,
        address updatedBy
    );

    event UpdatedCreatorRoyality(
        uint256 creatorRoyality,
        address updatedBy
    );

    event UpdatedPlatformRoyality(
        uint256 platformRoyality,
        address updatedBy
    );

    event UpdatedItemToNotForSale(
        uint256 itemID,
        bool itemStatus,
        bool openForOffer,
        uint256 minimumAllowedBid,
        address updatedBy
    );

    event UpdatedItemToPause(uint256 itemID, bool itemStatus, address updatedBy);
    event UpdatedItemToUnpause(uint256 itemID, bool itemStatus, address updatedBy);

    event NewItemAdded(
        uint256 itemID,
        address ownerAddress,
        string collection,
        uint256 price,
        bool openForSale,        
        bool openForOffer,
        uint256 minimumAllowedBid,
        bool paused,
        string itemMetaData
    );

    event UpdatedItemToOpenForSale(
        uint256 itemID,
        bool itemStatus,
        uint256 price,
        bool openForOffer,
        uint256 minimumAllowedBid,
        address updatedBy
    );

    event UpdatedItemPrice(uint256 itemID, uint256 price, address updatedBy);

    event UpdatedItemTokenMetaData(
        uint256 itemID,
        string itemMetaData,
        address updatedBy
    );

    event BaseURI(string baseTokenURI, address addedBy);
    
    constructor() ERC721("NFTContract", "NFTC") {
        platformWallet = payable(0xb3982EC3a97943554b23f186247Ea6522C25DD29);
        creatorRoyality = 1;
        platformRoyality = 2;
    }

    function updatePlatformWalletAddress(address newWallet)
        public
        onlyOwner
        returns (bool)
    {
        platformWallet = payable(newWallet);

        emit UpdatedPlatformWalletAddress(platformWallet, msg.sender);
    }

    function updateCreatorRoyality(uint256 newRoyality)
        public
        onlyOwner
        returns (bool)
    {
        creatorRoyality = newRoyality;

        emit UpdatedCreatorRoyality(
            creatorRoyality,
            msg.sender
        );
    }

    function updatePlatformRoyality(uint256 newRoyality)
        public
        onlyOwner
        returns (bool)
    {
        platformRoyality = newRoyality;

        emit UpdatedPlatformRoyality(
            platformRoyality,
            msg.sender
        );
    }

    function addNewItem(
        address owner,
        string memory tokenURI,
        string memory collection
    ) public onlyOwner returns (uint256) {
        _tokenIds.increment();

        uint256 newItemID = _tokenIds.current();
        _mint(owner, newItemID);
        itemsOnProject[newItemID].owner = payable(owner);
        itemsOnProject[newItemID].collection = collection;
        itemsOnProject[newItemID].price = 0;
        itemsOnProject[newItemID].openForSale = false;
        itemsOnProject[newItemID].openForOffer = false;
        itemsOnProject[newItemID].minimumAllowedBid = 0;
        itemsOnProject[newItemID].paused = false;
        itemsOnProject[newItemID].itemMetaData = tokenURI;
        _setTokenURI(newItemID, tokenURI);

        emit NewItemAdded(
            newItemID,
            itemsOnProject[newItemID].owner,
            itemsOnProject[newItemID].collection,
            itemsOnProject[newItemID].price,
            itemsOnProject[newItemID].openForSale,
            itemsOnProject[newItemID].openForOffer,
            itemsOnProject[newItemID].minimumAllowedBid,
            itemsOnProject[newItemID].paused,
            itemsOnProject[newItemID].itemMetaData
        );

        return newItemID;
    }

    function UpdateItemToNotForSale(uint256 itemID)
        public
        whenNotPaused
        returns (bool)
    {
        require(itemsOnProject[itemID].owner == msg.sender, "Invalid Owner");
        require(
            itemsOnProject[itemID].openForSale == true,
            "Item already on Open For Sale"
        );

        itemsOnProject[itemID].openForSale = false;
        itemsOnProject[itemID].openForOffer = false;
        itemsOnProject[itemID].minimumAllowedBid = 0;

        emit UpdatedItemToNotForSale(
            itemID,
            itemsOnProject[itemID].openForSale,
            itemsOnProject[itemID].openForOffer,
            itemsOnProject[itemID].minimumAllowedBid,
            msg.sender
        );
        return true;
    }

    function UpdateItemToOpenForSale(
        uint256 itemID,
        uint256 price,
        bool enableBidOnItem,
        uint256 minimumAllowedBid
    ) public whenNotPaused returns (bool) {
        require(itemsOnProject[itemID].owner == msg.sender, "Invalid Owner");
        require(
            itemsOnProject[itemID].openForSale == false,
            "Item already on Open For Sale"
        );

        itemsOnProject[itemID].openForSale = true;
        itemsOnProject[itemID].openForOffer = enableBidOnItem;
        itemsOnProject[itemID].minimumAllowedBid = minimumAllowedBid;
        itemsOnProject[itemID].price = price;

        emit UpdatedItemToOpenForSale(
            itemID,
            itemsOnProject[itemID].openForSale,
            price,
            itemsOnProject[itemID].openForOffer,
            itemsOnProject[itemID].minimumAllowedBid,
            msg.sender
        );
        return true;
    }

    function UpdateItemToPaused(uint256 itemID)
        public
        whenNotPaused
        returns (bool)
    {
        require(itemsOnProject[itemID].owner == msg.sender, "Invalid Owner");
        require(
            itemsOnProject[itemID].paused == false,
            "Item already with the same status"
        );
        itemsOnProject[itemID].paused = true;

        emit UpdatedItemToPause(
            itemID,
            itemsOnProject[itemID].paused,
            msg.sender
        );
        return true;
    }

    function UpdateItemToUnpaused(uint256 itemID)
        public
        whenNotPaused
        returns (bool)
    {
        require(itemsOnProject[itemID].owner == msg.sender, "Invalid Owner");
        require(
            itemsOnProject[itemID].paused == true,
            "Item already with the same status"
        );
        itemsOnProject[itemID].paused = false;

        emit UpdatedItemToUnpause(
            itemID,
            itemsOnProject[itemID].paused,
            msg.sender
        );

        return true;
    }

    function UpdateItemPrice(uint256 itemID, uint256 price)
        public
        whenNotPaused
        returns (bool)
    {
        require(itemsOnProject[itemID].owner == msg.sender, "Invalid Owner");

        itemsOnProject[itemID].price = price;

        emit UpdatedItemPrice(itemID, price, msg.sender);

        return true;
    }

    function UpdateItemTokenMetaData(
        uint256 itemID,
        string memory itemMetaData
    ) public whenNotPaused returns (bool) {
        require(itemsOnProject[itemID].owner == msg.sender, "Invalid Owner");

        itemsOnProject[itemID].itemMetaData = itemMetaData;
        _setTokenURI(itemID, itemMetaData);

        emit UpdatedItemTokenMetaData(
            itemID,
            itemsOnProject[itemID].itemMetaData,
            msg.sender
        );

        return true;
    }

    function setBaseTokenURI(string memory baseTokenURI)
        public
        onlyOwner
        returns (bool)
    {
        _setBaseURI(baseTokenURI);

        emit BaseURI(baseTokenURI, msg.sender);

        return true;
    }

    function buyItem(uint256 itemID)
        public
        payable
        whenNotPaused
        returns (bool)
    {
        require(
            itemsOnProject[itemID].owner != msg.sender,
            "You cannot purchase your own Item"
        );
        require(
            itemsOnProject[itemID].paused == false,
            "Item is paused for trade"
        );
        require(
            itemsOnProject[itemID].openForSale == true,
            "Item not available for sale"
        );
        require(
            itemsOnProject[itemID].price == (msg.value * 1 ether),
            "Price is not same"
        );
        
        uint256 calculatePlatformRoyality = SafeMath.mul(msg.value, platformRoyality); 
        uint256 calculateCreatorRoyality = SafeMath.mul(msg.value, creatorRoyality); 

        platformWallet.transfer(calculatePlatformRoyality);
        itemsOnProject[itemID].owner.transfer(calculateCreatorRoyality);
        
        _transfer(itemsOnProject[itemID].owner, msg.sender, itemID);

        itemsOnProject[itemID].ownershipTransferCount.increment();

        itemsOnProject[itemID].ownershipTransferTransaction[
            itemsOnProject[itemID].ownershipTransferCount.current()
        ]
            .owner = msg.sender;
        itemsOnProject[itemID].ownershipTransferTransaction[
            itemsOnProject[itemID].ownershipTransferCount.current()
        ]
            .purchasedPrice = msg.value;
        itemsOnProject[itemID].ownershipTransferTransaction[
            itemsOnProject[itemID].ownershipTransferCount.current()
        ]
            .timestamp = block.timestamp;

        itemsOnProject[itemID].openForSale = false;
        itemsOnProject[itemID].owner = payable(msg.sender);

        emit PurchasedItem(itemID, msg.sender, msg.value, msg.sender);
        emit ownershipTransferredOfItem(
            itemID,
            itemsOnProject[itemID].ownershipTransferCount.current(),
            msg.sender,
            msg.value,
            msg.sender
        );

        return true;
    }

    function getItemDetail(uint256 itemID)
        public
        view
        returns (
            address,
            string memory,
            uint256,
            bool,
            string memory,
            uint256
        )
    {
        return (
            itemsOnProject[itemID].owner,
            itemsOnProject[itemID].collection,
            itemsOnProject[itemID].price,
            itemsOnProject[itemID].openForSale,
            itemsOnProject[itemID].itemMetaData,
            itemsOnProject[itemID].ownershipTransferCount.current()
        );
    }

    function getItemOwnerTransferDetail(
        uint256 itemID,
        uint256 transactionID
    )
        public
        view
        returns (
            address,
            uint256,
            uint256
        )
    {
        return (
            itemsOnProject[itemID].ownershipTransferTransaction[transactionID]
                .owner,
            itemsOnProject[itemID].ownershipTransferTransaction[transactionID]
                .purchasedPrice,
            itemsOnProject[itemID].ownershipTransferTransaction[transactionID]
                .timestamp
        );
    }
}