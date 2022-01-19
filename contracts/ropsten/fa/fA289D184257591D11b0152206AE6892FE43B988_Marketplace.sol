// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Marketplace is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    /// @notice Types of offer
    enum Types {
        regular,
        auction
    }

    /// @notice Bid object
    struct Bid {
        address payable buyer;
        uint256 amount;
        bool isWinner;
        bool isChargedBack;
    }

    /// @notice Lot object
    struct Lot {
        address nft;
        address payable seller;
        uint256 tokenId;
        Types offerType;
        uint256 price;
        uint256 stopPrice;
        uint256 auctionStart;
        uint256 auctionEnd;
        bool isSold;
        bool isCanceled;
    }

    /// @notice This multiplier allows us to use the fractional part for the commission
    uint256 private constant FEES_MULTIPLIER = 10000;

    /// @notice Marketplace fee
    /// @dev 1 == 0.01%
    uint256 public serviceFee;

    /// @notice Address that will receive marketplace fees
    address payable public feesCollector;

    /// @notice Users who are not allowed to the marketplace
    mapping(address => bool) public banList;

    /// @notice All lots IDs of the seller
    /// @dev Current and past lots
    mapping(address => uint256[]) private lotsOfSeller;

    /// @notice All bids of lot
    mapping(uint256 => Bid[]) public bidsOfLot;

    /// @notice Array of lots
    Lot[] public lots;

    /// @notice Events
    event ServiceFeeChanged(uint256 newFee);
    event UserBanStatusChanged(address user, bool isBanned);
    event TokenRemovedFromSale(uint256 lotId, bool removedBySeller);
    event Sold(uint256 lotId, address buyer, uint256 price, uint256 fee);
    event RegularLotCreated(uint256 lotId);
    event AuctionLotCreated(uint256 lotId);

    /// @notice Acts like constructor() for upgradeable contracts
    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        feesCollector = payable(msg.sender);
        serviceFee = 100;
    }

    /// @notice Allow this contract to receive ether
    receive() external payable {}

    /**
     * @notice Checks that the user is not banned
     */
    modifier notBanned() {
        require(!banList[msg.sender], "you are banned");
        _;
    }

    /**
     * @notice Checks that the lot has not been sold or canceled
     * @param lotId - ID of the lot
     */
    modifier lotIsActive(uint256 lotId) {
        Lot memory lot = lots[lotId];
        require(!lot.isSold, "lot already sold");
        require(!lot.isCanceled, "lot canceled");
        _;
    }

    /**
     * @notice Get all lots of the seller
     * @param seller - Address of seller
     * @return array of lot IDs
     */
    function getLotsOfSeller(address seller)
        external
        view
        returns (uint256[] memory)
    {
        return lotsOfSeller[seller];
    }

    /**
     * @notice Get all bids of the lot
     * @param lotId - ID of lot
     * @return array of lot IDs
     */
    function getBidsOfLot(uint256 lotId) external view returns (Bid[] memory) {
        return bidsOfLot[lotId];
    }

    /**
     * @notice Get bids of the user by lot Id
     * @param bidder - User's address
     * @param lotId - ID of lot
     * @return _bid - Return bid
     */
    function getBidsOf(address bidder, uint256 lotId)
        external
        view
        returns (Bid memory _bid)
    {
        for (uint256 i = 0; i < bidsOfLot[lotId].length; i++) {
            _bid = bidsOfLot[lotId][i];
            if (_bid.buyer == bidder && !_bid.isChargedBack) {
                return _bid;
            }
        }
        revert("bid not found");
    }

    /**
     * @notice Change marketplace fee
     * @param newServiceFee - New fee amount
     */
    function setServiceFee(uint256 newServiceFee) external onlyOwner {
        require(serviceFee != newServiceFee, "similar amount");
        serviceFee = newServiceFee;
        emit ServiceFeeChanged(newServiceFee);
    }

    /**
     * @notice Change user's ban status
     * @param user - Address of account
     * @param isBanned - Status of account
     */
    function setBanStatus(address user, bool isBanned) external onlyOwner {
        require(banList[user] != isBanned, "address already have this status");
        banList[user] = isBanned;
        emit UserBanStatusChanged(user, isBanned);
    }

    /**
     * @notice Remove lot from sale and return users funds
     * @dev Only lot owner or contract owner can do this
     * @param lotId - ID of the lot
     */
    function removeLot(uint256 lotId) external nonReentrant {
        Lot memory lot = lots[lotId];
        require(!lot.isSold, "lot already sold");
        require(
            msg.sender == lot.seller || msg.sender == owner(),
            "only owner or seller can remove"
        );
        lot.isCanceled = true;
        if (lot.offerType == Types.auction) {
            // send funds to bidders
            Bid[] memory bids = bidsOfLot[lotId];
            for (uint256 i = 0; i < bids.length; i++) {
                Bid memory _bid = bids[i];
                if (!_bid.isChargedBack && !_bid.isWinner) {
                    _bid.isChargedBack = true;
                    (bool sent, ) = _bid.buyer.call{value: _bid.amount}("");
                    require(sent, "something went wrong");
                }
            }
        }
        // send NFT back to the seller
        IERC721Upgradeable(lot.nft).safeTransferFrom(
            address(this),
            lot.seller,
            lot.tokenId
        );
        emit TokenRemovedFromSale(lotId, msg.sender == lot.seller);
    }

    /**
     * @notice Buy regular lot (not auction)
     * @param lotId - ID of the lot
     */
    function buy(uint256 lotId)
        external
        payable
        notBanned
        lotIsActive(lotId)
        nonReentrant
    {
        Lot storage lot = lots[lotId];
        require(lot.offerType == Types.regular, "only regular lot type");
        require(msg.value == lot.price, "wrong ether amount");
        _buy(lot, lot.price, lotId);
    }

    /**
     * @notice Make auction bid
     * @param lotId - ID of the lot
     */
    function bid(uint256 lotId)
        external
        payable
        notBanned
        lotIsActive(lotId)
        nonReentrant
    {
        Lot storage lot = lots[lotId];
        require(lot.offerType == Types.auction, "only auction lot type");
        require(
            lot.auctionStart <= block.timestamp,
            "auction is not started yet"
        );
        require(lot.auctionEnd >= block.timestamp, "auction already finished");
        Bid[] storage bids = bidsOfLot[lotId];
        uint256 bidAmount = msg.value;
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].buyer == msg.sender && !bids[i].isChargedBack) {
                bidAmount += bids[i].amount;
            }
        }
        require(
            bidAmount <= lot.stopPrice,
            "amount should be less or equal to stop price"
        );
        require(
            bidAmount >= lot.price,
            "amount should be great or equal to lot price"
        );
        if (bids.length > 0) {
            require(
                bids[bids.length - 1].amount < bidAmount,
                "bid should be greater than last"
            );
        }
        // Pay
        (bool fundsInMarketplace, ) = payable(address(this)).call{
            value: msg.value
        }("");
        require(fundsInMarketplace, "payment error (bidder)");
        Bid memory newBid = Bid(payable(msg.sender), bidAmount, false, false);
        // Do not send funds to previous bids, because this amount in last bid
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].buyer == msg.sender && !bids[i].isChargedBack) {
                bids[i].isChargedBack = true;
            }
        }
        bids.push(newBid);
        // finalize when target price reached
        if (bidAmount == lot.stopPrice) {
            lot.auctionEnd = block.timestamp - 1;
            _finalize(lotId);
        }
    }

    /**
     * @notice Finalize auction (external function)
     * @param lotId - ID of the lot
     */
    function finalize(uint256 lotId)
        external
        payable
        notBanned
        lotIsActive(lotId)
        nonReentrant
    {
        _finalize(lotId);
    }

    /**
     * @notice Finalize auction (internal function)
     * @param lotId - ID of the lot
     */
    function _finalize(uint256 lotId) internal {
        Lot storage lot = lots[lotId];
        Bid[] storage bids = bidsOfLot[lotId];
        require(bids.length > 0, "no bids");
        require(
            lot.auctionEnd < block.timestamp,
            "auction is not finished yet"
        );
        uint256 winnerId;
        if (bids.length == 1) {
            winnerId = 0;
        } else {
            winnerId = bids.length - 1;
            for (uint256 i = 0; i < bids.length - 1; i++) {
                Bid storage _bid = bids[i];
                if (!_bid.isChargedBack) {
                    _bid.isChargedBack = true;
                    _bid.buyer.call{value: _bid.amount}("");
                }
            }
        }
        bids[winnerId].isWinner = true;
        _buy(lot, bids[winnerId].amount, lotId);
    }

    /**
     * @notice Send funds and token
     * @param lot - Lot to buy
     * @param price - Lot price
     * @param lotId - ID of the lot
     */
    function _buy(
        Lot storage lot,
        uint256 price,
        uint256 lotId
    ) internal {
        uint256 fee = (price * serviceFee) / FEES_MULTIPLIER;
        (bool payedToSeller, ) = lot.seller.call{value: price - fee}("");
        require(payedToSeller, "payment error (seller)");
        (bool payedToFeesCollector, ) = feesCollector.call{value: fee}("");
        require(payedToFeesCollector, "payment error (fees collector)");
        lot.isSold = true;
        IERC721Upgradeable(lot.nft).safeTransferFrom(
            address(this),
            msg.sender,
            lot.tokenId
        );
        emit Sold(lotId, msg.sender, price, fee);
    }

    /**
     * @notice Regular offer (not auction)
     * @param nft - Address of NFT contract
     * @param tokenId - ID of token to sale
     * @param price - Token price
     * @return _lotId - Lot ID
     */
    function makeRegularOffer(
        address nft,
        uint256 tokenId,
        uint256 price
    ) external notBanned returns (uint256 _lotId) {
        require(nft != address(0), "zero address for NFT");
        require(price > 0, "price should be greater than 0");
        IERC721Upgradeable(nft).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        Lot memory newLot = Lot(
            nft,
            payable(msg.sender),
            tokenId,
            Types.regular,
            price,
            0,
            0,
            0,
            false,
            false
        );
        lots.push(newLot);
        _lotId = lots.length - 1;
        lotsOfSeller[msg.sender].push(_lotId);
        emit RegularLotCreated(_lotId);
    }

    /**
     * @notice Regular offer (not auction)
     * @param nft - Address of NFT contract
     * @param tokenId - ID of token to sale
     * @param price - Token price
     * @param stopPrice - Price to stop auction and sale immediately
     * @param auctionStart - Auction starts at
     * @param auctionEnd - Auction finish at
     * @return _lotId - Lot ID
     */
    function makeAuctionOffer(
        address nft,
        uint256 tokenId,
        uint256 price,
        uint256 stopPrice,
        uint256 auctionStart,
        uint256 auctionEnd
    ) external notBanned returns (uint256 _lotId) {
        require(nft != address(0), "zero address");
        require(
            auctionStart > 0,
            "auction start time should be greater than 0"
        );
        require(
            auctionEnd > auctionStart,
            "auction end time should be greater than auction start time"
        );
        require(price > 0, "price should be greater than 0");
        require(stopPrice > price, "stop price should be greater than price");
        IERC721Upgradeable(nft).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        Lot memory newLot = Lot(
            nft,
            payable(msg.sender),
            tokenId,
            Types.auction,
            price,
            stopPrice,
            auctionStart,
            auctionEnd,
            false,
            false
        );
        lots.push(newLot);
        _lotId = lots.length - 1;
        lotsOfSeller[msg.sender].push(_lotId);
        emit AuctionLotCreated(_lotId);
    }

    /// @notice To make ERC721 safeTransferFrom works
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes memory _data
    ) external pure returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }
}