pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../libs/IWETH.sol";

contract NFTMarketWETH {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _bidItems;
    address public immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address payable owner;

    constructor() {
        owner = payable(msg.sender);
    }

    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable buyer;
        address payable owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    mapping(uint256 => BidItem) private itemIdToBids;

    mapping(uint256 => bool) public itemIdExists;

    mapping(uint256 => bool) public bidItemIdExists;

    struct BidItem {
        uint256 bidId;
        uint256 itemId;
        uint256 price;
        uint256 expiry;
        address buyer;
    }

    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner!");
        _;
    }

    modifier onlySeller(address _seller, uint256 itemId) {
        require(itemIdExists[itemId],"Item Id does not Exist!");
        require(idToMarketItem[itemId].owner == _seller, "Not the NFT Seller!");
        _;
    }

    modifier notASeller(address _buyer, uint256 itemId) {
        require(itemIdExists[itemId],"Item Id does not Exist!");
        require(idToMarketItem[itemId].owner != _buyer, "Cannot be a Buyer!");
        _;
    }

    /* Returns the listing price of the contract */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /* Returns the listing price of the listed Item Id */
    function getListingPrice(uint256 itemID) public view returns (uint256) {
        return idToMarketItem[itemID].price;
    }

    /* Places an item for sale on the marketplace */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public payable returns (uint256) {
        require(price > 0, "Invalid Price");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(address(0)),
            payable(msg.sender),
            price,
            false
        );
         
        itemIdExists[itemId] = true; 
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        return itemId;
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
    function acceptBidByApproving(address nftContract, uint256 itemId, uint256 bidItemId)
        public
        payable
        onlySeller(msg.sender, itemId)
    {
        require(bidItemIdExists[bidItemId],"bid Item Id does not Exist");
        require(itemIdToBids[bidItemId].itemId == itemId, "Bid is not placed for the current market item!");
        uint256 price = itemIdToBids[bidItemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        IERC20(WETH).safeTransferFrom(itemIdToBids[bidItemId].buyer,msg.sender,price);
        IERC721(nftContract).approve(itemIdToBids[bidItemId].buyer, tokenId);
        IERC721(nftContract).safeTransferFrom(address(this), itemIdToBids[bidItemId].buyer, tokenId);
        idToMarketItem[itemId].buyer = payable(itemIdToBids[bidItemId].buyer);
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();
    }

    function bidMarketItem(
        uint256 itemId,
        uint256 price,
        uint256 expiry
    ) public notASeller(msg.sender, itemId) returns (uint256) {
        uint256 askPrice = idToMarketItem[itemId].price;
        require(!idToMarketItem[itemId].sold, "NFT is already sold");
        require(
            IERC20(WETH).balanceOf(msg.sender) >= price,
            "WETH not sufficient to bid on the Item"
        );
        require(
            price >= askPrice,
            "Bid price cannot be lower than Ask price"
        );
        require(
            IWETH(WETH).allowance(msg.sender,address(this)) >= price,
            "approved amount is not sufficient for the bid"
        );
        _bidItems.increment();
        uint256 bidItemId = _bidItems.current();
        itemIdToBids[bidItemId] = BidItem(
            bidItemId,
            itemId,
            price,
            expiry,
            msg.sender
        );
        bidItemIdExists[bidItemId] = true;
        return bidItemId;
    }

    /* Returns all unsold market items */
    function fetchMarketItems()
        public
        view
        onlyOwner
        returns (MarketItem[] memory)
    {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i + 1].owner == address(0)) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns onlyl items that a user has purchased */
    function fetchMyNFTs()
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns items a user has created */
    function fetchAllMarketItemsUnsold()
        public
        view
        onlyOwner
        returns (MarketItem[] memory)
    {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].sold == false) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](totalItemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
        }
        return items;
    }
}