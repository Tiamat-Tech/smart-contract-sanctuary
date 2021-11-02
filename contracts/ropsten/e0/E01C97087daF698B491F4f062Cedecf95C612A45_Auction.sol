// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./NFTMarket.sol";

import "hardhat/console.sol";

contract Auction is NFTMarket {
    struct AuctionDetail {
        uint256 itemId;
        uint256 reservePrice;
        uint256 startTime;
        uint256 duration;
        uint256 currentBidPrice;
        address currentBidder;
    }

    mapping(uint256 => AuctionDetail) auctionDetails;

    event AuctionCreated(
        uint256 indexed itemId,
        address tokenContract,
        uint256 tokenId,
        address indexed owner,
        uint256 reservePrice,
        uint256 duration
    );

    event AuctionBid(
        uint256 indexed itemId,
        address indexed bidder,
        uint256 price
    );

    event AuctionEnded(
        uint256 indexed itemId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        address seller,
        address winner,
        uint256 endingPrice
    );

    event AuctionCanceled(
        uint256 indexed itemId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        address seller
    );
    event AuctionReservePriceChanged(
        uint256 indexed itemId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 reservePrice
    );

    event Claim(uint256 indexed id, address claimer);

    enum Status {
        PENDING,
        ACTIVE,
        FINISHED
    }

    constructor(address _pauser, address _weth) NFTMarket(_pauser, _weth) {}

    function createAuctionItem(
        address _tokenContract,
        uint256 _tokenId,
        address _paymentToken,
        uint256 _price
    ) external whenNotPaused {
        _createMarketItem(
            _tokenContract,
            _tokenId,
            _paymentToken,
            _price,
            true
        );
    }

    function startAuction(
        uint256 _itemId,
        uint256 _reservePrice,
        uint256 _numberOfDays
    ) external whenNotPaused {
        MarketItem storage _item = marketItems[_itemId];

        require(
            _item.seller == msg.sender,
            "Only owner can put his item on auction."
        );
        require(!_item.isAuctionItem, "Item is already on auction");

        _item.isAuctionItem = true;
        auctionDetails[_itemId] = AuctionDetail(
            _itemId,
            _reservePrice,
            0,
            (_numberOfDays * 24 * 60 * 60),
            0,
            address(0)
        );

        emit AuctionCreated(
            _itemId,
            _item.tokenContract,
            _item.tokenId,
            _item.seller,
            _reservePrice,
            (_numberOfDays * 1 days)
        );
    }

    function setReservePrice(uint256 _itemId, uint256 _newPrice)
        external
        whenNotPaused
    {
        MarketItem memory _item = marketItems[_itemId];
        // Only seller can change the reserve price
        require(
            _item.seller == msg.sender,
            "Auction: only the seller can change the price"
        );

        AuctionDetail storage _detail = auctionDetails[_itemId];
        // Once bidding started, the reserve price can't be changed
        require(
            _detail.startTime == 0,
            "Auction: during auction, reserve price can't be changed"
        );

        _detail.reservePrice = _newPrice;

        emit AuctionReservePriceChanged(
            _itemId,
            _item.tokenContract,
            _item.tokenId,
            _newPrice
        );
    }

    // TODO: MINIMUM BID(percentage) requirement
    function placeBid(uint256 _itemId, uint256 _price)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        MarketItem memory _item = marketItems[_itemId];

        // Check the item is on auction sale
        require(
            _item.isAuctionItem,
            "Auction: can't place bid to a non-aution item"
        );

        // Do not allow bidding his own item
        require(
            _item.seller != msg.sender,
            "Auction: can't bid to his own item"
        );

        AuctionDetail storage _detail = auctionDetails[_itemId];

        // Check if it is first bid(the first bid starts the auction) or the auction is not expired
        require(
            _detail.startTime == 0 ||
                block.timestamp < (_detail.startTime + _detail.duration),
            "Auction: auction expired"
        );

        // Check if the bid is equal or above the reserve price
        require(
            _price >= _detail.reservePrice,
            "Auction: bid price is too low"
        );
        // TODO:  could be combine with the above 'require' check
        // Check if bidding price is greater than the previous bid
        require(
            _price > _detail.currentBidPrice,
            "Auction: bid price should be bigger than the current bid"
        );

        address _currentBidder = _detail.currentBidder;
        uint256 _currentBidPrice = _detail.currentBidPrice;

        // First receive payment from the outbidder
        _receiveIncomingPayment(_price, _item.paymentToken);

        // If there is a previous bid, return payment to the previous bidder
        if (_currentBidPrice != 0) {
            _sendOutgoingPayment(
                _currentBidder,
                _currentBidPrice,
                _item.paymentToken
            );
        }

        // Update the status of bidding
        // The first valid bid starts the auction
        if (_detail.startTime == 0) {
            _detail.startTime = block.timestamp;
        }

        _detail.currentBidder = msg.sender;
        _detail.currentBidPrice = _price;

        emit AuctionBid(_itemId, msg.sender, _price);
    }

    function endAuction(uint256 _itemId) external whenNotPaused {
        MarketItem storage _item = marketItems[_itemId];
        require(_item.isAuctionItem, "Auction: item is not on auction");

        AuctionDetail memory _detail = auctionDetails[_itemId];

        require(_detail.startTime != 0, "Auction: auction hasn't been started");
        require(
            block.timestamp > (_detail.startTime + _detail.duration),
            "Auction: auction hasn't been finished"
        );

        // Handover token and payment
        IERC721(_item.tokenContract).transferFrom(
            address(this),
            _detail.currentBidder,
            _item.tokenId
        );

        // TODO: handle market fee
        _sendOutgoingPayment(
            _item.seller,
            _detail.currentBidPrice,
            _item.paymentToken
        );

        emit AuctionEnded(
            _itemId,
            _item.tokenContract,
            _item.tokenId,
            _item.seller,
            _detail.currentBidder,
            _detail.currentBidPrice
        );

        delete auctionDetails[_itemId];
        delete marketItems[_itemId];
    }

    function cancelAuction(uint256 _itemId) external whenNotPaused {
        MarketItem storage _item = marketItems[_itemId];

        // item should be on auction sale
        require(_item.isAuctionItem, "Auction: it is not an auction item.");

        // only seller can cancel this auction
        require(
            _item.seller == msg.sender,
            "Auction: only the seller can cancel the auction"
        );

        AuctionDetail memory _detail = auctionDetails[_itemId];
        require(
            _detail.startTime == 0,
            "Auction: already received bids. It can't be canceled"
        );

        delete auctionDetails[_itemId];
        _item.isAuctionItem = false;

        emit AuctionCanceled(
            _itemId,
            _item.tokenContract,
            _item.tokenId,
            _item.seller
        );
    }

    receive() external payable {}

    fallback() external payable {}
}