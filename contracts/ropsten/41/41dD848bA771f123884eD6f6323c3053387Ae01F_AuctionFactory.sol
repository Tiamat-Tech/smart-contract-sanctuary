//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IAuctionFactory.sol";

contract AuctionFactory is IAuctionFactory, IERC721Receiver {
    using SafeMath for uint256;

    struct DepositedERC721 {
        address tokenAddress;
        uint256 tokenId;
        uint256 auctionId;
        uint256 slotIndex;
    }

    struct Slot {
        DepositedERC721[] nfts;
    }

    struct Auction {
        address auctionOwner;
        uint256 startBlockNumber;
        uint256 endBlockNumber;
        uint256 resetTimer;
        uint256 numberOfSlots;
        bool supportWhiteList;
        mapping(address => bool) isWhiteListed;
        Slot[] slots;
    }

    // totalAuctions
    uint256 public totalAuctions;

    // auctionId -> Auction
    mapping(uint256 => Auction) public auctions;

    event LogERC721Deposit(
        address depositor,
        address tokenAddress,
        uint256 tokenId,
        uint256 auctionId,
        uint256 slotIndex,
        uint256 time
    );

    event LogAuctionCreated(
        uint256 auctionId,
        address auctionOwner,
        uint256 numberOfSlots
    );

    constructor() {}

    function createAuction(
        uint256 _startBlockNumber,
        uint256 _endBlockNumber,
        uint256 _resetTimer,
        uint256 _numberOfSlots,
        address[] calldata _whitelistedAddresses
    ) external override returns (uint256) {
        require(
            _endBlockNumber > _startBlockNumber,
            "End block number should be higher than start block number"
        );

        require(_resetTimer > 0, "Reset timer should be higher than 0 seconds");

        require(_numberOfSlots > 0, "Number of slots should be higher than 0");

        totalAuctions = totalAuctions.add(1);

        Auction storage auction = auctions[totalAuctions];

        auction.startBlockNumber = _startBlockNumber;
        auction.endBlockNumber = _endBlockNumber;
        auction.resetTimer = _resetTimer;
        auction.numberOfSlots = _numberOfSlots;

        if (_whitelistedAddresses.length > 0) {
            for (uint256 idx = 0; idx < _whitelistedAddresses.length; idx++) {
                address whitelistedAddress = _whitelistedAddresses[idx];

                require(
                    whitelistedAddress != address(0),
                    "Address zero provided in array with whitelisted addresses"
                );

                require(
                    !auction.isWhiteListed[whitelistedAddress],
                    "Duplication in array with whitelisted addresses"
                );

                auction.isWhiteListed[whitelistedAddress] = true;
            }

            auction.supportWhiteList = true;
        }

        emit LogAuctionCreated(totalAuctions, msg.sender, _numberOfSlots);

        return totalAuctions;
    }

    function depositERC721(
        uint256 auctionId,
        uint256 slotIndex,
        uint256 tokenId,
        address tokenAddress
    ) external override returns (bool) {
        require(
            tokenAddress != address(0),
            "Zero address was provided for token address"
        );

        address depositor = msg.sender;

        Auction storage auction = auctions[auctionId];

        if (auction.supportWhiteList) {
            require(
                auction.isWhiteListed[depositor],
                "You are not allowed to deposit in this auction"
            );
        }

        require(
            auction.numberOfSlots > slotIndex,
            "You are trying to deposit to a non-existing slot"
        );

        DepositedERC721 memory item;

        item.tokenAddress = tokenAddress;
        item.tokenId = tokenId;
        item.auctionId = auctionId;
        item.slotIndex = slotIndex;

        if (auction.slots[slotIndex].nfts.length == 0) {}

        auction.slots[slotIndex].nfts.push(item);

        IERC721(tokenAddress).safeTransferFrom(
            depositor,
            address(this),
            tokenId
        );

        emit LogERC721Deposit(
            depositor,
            tokenAddress,
            tokenId,
            auctionId,
            slotIndex,
            block.timestamp
        );

        return true;
    }

    function bid(uint256 auctionId, uint256 amount)
        external
        override
        returns (bool)
    {}

    function finalize(uint256 auctionId) external override returns (bool) {}

    function withdrawBid(uint256 auctionId) external override returns (bool) {}

    function matchBidToSlot(uint256 auctionId, uint256 amount)
        external
        override
        returns (uint256)
    {}

    function cancelAuction(uint256 auctionId)
        external
        override
        returns (bool)
    {}

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver(0).onERC721Received.selector;
    }
}