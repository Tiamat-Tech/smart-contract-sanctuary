// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "./interfaces/IAuction.sol";

contract Auction is IAuction, AccessControlUpgradeable {
    bytes32 public constant OWNER_AUCTION_ROLE =
        keccak256("OWNER_TRADING_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    mapping(uint256 => AuctionLot) internal _auctionLots;

    uint256 public override lastId;

    function init(address _marketplace) external initializer returns (bool) {
        _setupRole(OWNER_AUCTION_ROLE, msg.sender);
        _setRoleAdmin(OWNER_AUCTION_ROLE, OWNER_AUCTION_ROLE);
        _setRoleAdmin(MARKETPLACE_ROLE, OWNER_AUCTION_ROLE);
        _setupRole(MARKETPLACE_ROLE, _marketplace);

        return true;
    }

    modifier onlyOwner() {
        require(
            hasRole(OWNER_AUCTION_ROLE, msg.sender),
            "Caller is not an owner"
        );
        _;
    }

    modifier onlyMarketplace() {
        require(
            hasRole(MARKETPLACE_ROLE, msg.sender),
            "Caller is not a marketplace"
        );
        _;
    }

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

    function getBidInfo(uint256 auctionId)
        external
        view
        returns (address lasBidder, uint256 lastBid)
    {
        lasBidder = _auctionLots[auctionId].lastBidder;
        lastBid = _auctionLots[auctionId].lastBid;
    }

    function getAuctionInfo(uint256 auctionId)
        external
        view
        override
        returns (AuctionLot memory auctionLot)
    {
        auctionLot = _auctionLots[auctionId];
    }

    function addBid(
        uint256 auctionId,
        uint256 newBid,
        address newBidder
    ) external override {
        _auctionLots[auctionId].lastBidder = newBidder;
        _auctionLots[auctionId].lastBid = newBid;
    }

    function extendActionLifeTime(uint256 auctionId, uint128 additionalTime)
        external
        override
        onlyMarketplace
    {
        _auctionLots[auctionId].endTime += additionalTime;
    }

    function getOwner(uint256 auctionId)
        external
        view
        override
        returns (address)
    {
        return _auctionLots[auctionId].auctionCreator;
    }

    function editAuctionLot(
        uint256 auctionId,
        uint256 amount,
        uint256 startPrice,
        uint128 startTime,
        uint128 endTime,
        uint128 minDelta
    ) external override onlyMarketplace {
        _auctionLots[auctionId].amount = amount;
        _auctionLots[auctionId].startPrice = startPrice;
        _auctionLots[auctionId].startTime = startTime;
        _auctionLots[auctionId].endTime = endTime;
        _auctionLots[auctionId].minDelta = minDelta;
    }

    function delAuctionLot(uint256 auctionId)
        external
        override
        onlyMarketplace
    {
        delete _auctionLots[auctionId];
    }
}