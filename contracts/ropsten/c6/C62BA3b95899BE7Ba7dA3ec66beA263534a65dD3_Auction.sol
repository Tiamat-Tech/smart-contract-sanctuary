// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/IAuction.sol";

/// @title Auction Contract
/// @dev Contract for create/edit/delete auction lots
/// @dev Only Marketplace contract can use functions that change auction entity

contract Auction is IAuction, AccessControlUpgradeable {
    bytes32 public constant OWNER_AUCTION_ROLE =
        keccak256("OWNER_TRADING_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    mapping(uint256 => AuctionLot) internal _auctionLots;

    uint256 public override lastId;

    /// @dev Check if caller is contract owner

    modifier onlyOwner() {
        require(
            hasRole(OWNER_AUCTION_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }

    /// @dev Check if caller is marketplace contract

    modifier onlyMarketplace() {
        require(
            hasRole(MARKETPLACE_ROLE, msg.sender),
            "Caller is not a marketplace"
        );
        _;
    }

    /// @notice Contract initialization
    /// @dev Sets main dependencies and constants
    /// @param _marketplace marketplace contract address
    /// @return true if initialization complete success

    function init(address _marketplace) external initializer returns (bool) {
        _setupRole(OWNER_AUCTION_ROLE, msg.sender);
        _setRoleAdmin(OWNER_AUCTION_ROLE, OWNER_AUCTION_ROLE);
        _setRoleAdmin(MARKETPLACE_ROLE, OWNER_AUCTION_ROLE);
        _setupRole(MARKETPLACE_ROLE, _marketplace);

        return true;
    }

    /// @notice Return owner of auction by id
    /// @param auctionId id of auction
    /// @return address of auction owner

    function getOwner(uint256 auctionId)
        external
        view
        override
        returns (address)
    {
        return _auctionLots[auctionId].auctionCreator;
    }

    /// @notice Return info about last bid
    /// @dev Return two params of last bid. Value and address
    /// @param auctionId id of auction
    /// @return lasBidder lastBid. Address of last bidder and value of last bid

    function getBidInfo(uint256 auctionId)
        external
        view
        returns (address lasBidder, uint256 lastBid)
    {
        lasBidder = _auctionLots[auctionId].lastBidder;
        lastBid = _auctionLots[auctionId].lastBid;
    }

    /// @notice Returns full information about auction
    /// @dev Returns auction lot object by id with all params
    /// @param auctionId id of auction
    /// @return auctionLot auction object with all contains params

    function getAuctionInfo(uint256 auctionId)
        external
        view
        override
        returns (AuctionLot memory auctionLot)
    {
        auctionLot = _auctionLots[auctionId];
    }

    /// @notice Creates new auction
    /// @dev Creates new auction entity in mapping
    /// @param auctionCreator address of auction creator
    /// @param tokenId id of tokens, that use in this lot
    /// @param amount amount of tokens, that will sell in auction
    /// @param startPrice minimal price for first bid
    /// @param startTime timestamp when auction start
    /// @param endTime timestamp when auction end
    /// @param minDelta minimum difference between the past and the current bid
    /// @return id of new auction lot

    function addAuctionLot(
        address auctionCreator,
        uint256 tokenId,
        uint128 amount,
        uint256 startPrice,
        uint128 startTime,
        uint128 endTime,
        uint128 minDelta
    ) external override onlyMarketplace returns (uint256) {
        uint256 id = lastId;
        _auctionLots[id] = AuctionLot(
            tokenId,
            auctionCreator,
            amount,
            startPrice,
            startTime,
            endTime,
            minDelta,
            address(0),
            0
        );
        lastId++;
        return id;
    }

    /// @notice Place bid in auction
    /// @dev Rewrite last bid amount and last bidder address in auction entity
    /// @param auctionId id of auction
    /// @param newBid amount of new bid
    /// @param newBidder address of new bidder

    function addBid(
        uint256 auctionId,
        uint256 newBid,
        address newBidder
    ) external override onlyMarketplace {
        _auctionLots[auctionId].lastBidder = newBidder;
        _auctionLots[auctionId].lastBid = newBid;
    }

    /// @dev Increase endTime in auction entity
    /// @param auctionId id of auction
    /// @param additionalTime time in ms that will sum with endTime

    function extendActionLifeTime(uint256 auctionId, uint128 additionalTime)
        external
        override
        onlyMarketplace
    {
        _auctionLots[auctionId].endTime += additionalTime;
    }

    /// @notice Edit auction
    /// @dev Possible to edit only: amount, startPrice, startTime, endTime, minDelta
    /// @dev If some of params are will not change, should give them their previous value
    /// @param auctionId id of auction
    /// @param amount new or previous amount value
    /// @param startPrice new or previous startPrice value
    /// @param startTime new or previous startTime value
    /// @param endTime new or previous endTime value
    /// @param minDelta new or previous minDelta value

    function editAuctionLot(
        uint256 auctionId,
        uint256 amount,
        uint256 startPrice,
        uint128 startTime,
        uint128 endTime,
        uint128 minDelta
    ) external override onlyMarketplace {
        if (_auctionLots[auctionId].amount != amount) {
            _auctionLots[auctionId].amount = amount;
        }
        if (_auctionLots[auctionId].startPrice != startPrice) {
            _auctionLots[auctionId].startPrice = startPrice;
        }
        if (_auctionLots[auctionId].startTime != startTime) {
            _auctionLots[auctionId].startTime = startTime;
        }
        if (_auctionLots[auctionId].endTime != endTime) {
            _auctionLots[auctionId].endTime = endTime;
        }
        if (_auctionLots[auctionId].minDelta != minDelta) {
            _auctionLots[auctionId].minDelta = minDelta;
        }
    }

    /// @notice Delete auction from contract
    /// @dev Removes entity by id from mapping
    /// @param auctionId id of auction, that should delete

    function delAuctionLot(uint256 auctionId)
        external
        override
        onlyMarketplace
    {
        delete _auctionLots[auctionId];
    }
}