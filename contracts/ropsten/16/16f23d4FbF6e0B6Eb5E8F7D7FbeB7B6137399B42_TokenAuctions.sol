// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import "@openzeppelin/contracts/utils/Counters.sol";
import "./TokenSale.sol";

contract TokenAuctions is TokenSale {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    function _resetArtworkAuctionParams(uint256 artworkID) internal {
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidType = BidTypes.NONE;
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .minimumValidBid = 0;
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .reserveCheck = "";
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .expiryAuctionTimestamp = 0;
    }

    function _resetArtworkAuctionBidParams(uint256 artworkID, uint256 bidIndex)
        internal
    {
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[bidIndex]
            .amount = 0;
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[bidIndex]
            .beneficiaryAddress = payable(0x0);
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[bidIndex]
            .bidExpiryTimestamp = 0;
    }

    function _setArtworkAuctionParams(
        uint256 artworkID,
        BidTypes bidType,
        uint256 minimumValidBid,
        bytes32 reservePrice,
        uint256 expiryTimestamp
    ) internal {
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidType = bidType;
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .minimumValidBid = minimumValidBid;
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .reserveCheck = reservePrice;
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .expiryAuctionTimestamp = expiryTimestamp;
    }

    function enableAuctionOnArtwork(
        uint256 artworkID,
        BidTypes bidType,
        uint256 minimumValidBid,
        bytes32 reservePrice,
        uint256 expiryTimestamp
    ) external returns (bool) {
        _artworkStatusNotOpenForBid(artworkID);
        _onlyArtworkOwner(artworkID);
        _artworkStatusNotForSale(artworkID);
        _artworkNotPausedForTradeByContractOwner(artworkID);
        _artworkNotPausedForTrade(artworkID);

        if (bidType == BidTypes.TIMEDAUCTION) {
            require(
                expiryTimestamp > block.timestamp,
                "Expiry timestamp should be greater than current time"
            );
        } else if (bidType != BidTypes.UNLIMITEDAUCTION) {
            revert("Invalid Bidding type");
        }

        artworkOnXYZ[artworkID].openForBid = true;

        _setArtworkAuctionParams(
            artworkID,
            bidType,
            minimumValidBid,
            reservePrice,
            expiryTimestamp
        );

        safeTransferFrom(msg.sender, address(this), artworkID);

        // _transfer(msg.sender, address(this), artworkID);

        emit UpdatedArtworkToOpenForAuction(
            artworkID,
            artworkOnXYZ[artworkID].openForBid,
            minimumValidBid,
            expiryTimestamp,
            msg.sender
        );

        return true;
    }

    function cancelAuctionOnArtwork(uint256 artworkID) external returns (bool) {
        _artworkStatusOpenForBid(artworkID);
        _onlyArtworkOwner(artworkID);
        _artworkStatusNotForSale(artworkID);
        _artworkNotPausedForTrade(artworkID);
        _artworkNotPausedForTradeByContractOwner(artworkID);

        if (
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidType == BidTypes.TIMEDAUCTION
        ) {
            _artworkAuctionNotEnded(artworkID);
            _resetArtworkAuctionParams(artworkID);
            if (
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current() == 1
            ) {
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .openBidsOnAuction
                            .current()
                    ]
                    .beneficiaryAddress
                    .transfer(
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .bidsOnArtwork[
                                artworkOnXYZ[artworkID]
                                    .openArtworkAuction[
                                        artworkOnXYZ[artworkID].openForBid
                                    ]
                                    .openBidsOnAuction
                                    .current()
                            ]
                            .amount
                    );

                emit RefundedBidOnArtwork(
                    artworkID,
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .bidsOnArtwork[
                            artworkOnXYZ[artworkID]
                                .openArtworkAuction[
                                    artworkOnXYZ[artworkID].openForBid
                                ]
                                .openBidsOnAuction
                                .current()
                        ]
                        .beneficiaryAddress,
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .bidsOnArtwork[
                            artworkOnXYZ[artworkID]
                                .openArtworkAuction[
                                    artworkOnXYZ[artworkID].openForBid
                                ]
                                .openBidsOnAuction
                                .current()
                        ]
                        .amount
                );
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .decrement();
            }

            artworkOnXYZ[artworkID].openForBid = false;
        } else if (
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidType == BidTypes.UNLIMITEDAUCTION
        ) {
            uint256 availableBids = artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .current();

            if (availableBids > 0) {
                for (uint256 index = 1; index <= availableBids; index++) {
                    if (
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .bidsOnArtwork[index]
                            .amount != 0
                    ) {
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .bidsOnArtwork[index]
                            .beneficiaryAddress
                            .transfer(
                                artworkOnXYZ[artworkID]
                                    .openArtworkAuction[
                                        artworkOnXYZ[artworkID].openForBid
                                    ]
                                    .bidsOnArtwork[index]
                                    .amount
                            );

                        emit RefundedBidOnArtwork(
                            artworkID,
                            artworkOnXYZ[artworkID]
                                .openArtworkAuction[
                                    artworkOnXYZ[artworkID].openForBid
                                ]
                                .bidsOnArtwork[index]
                                .beneficiaryAddress,
                            artworkOnXYZ[artworkID]
                                .openArtworkAuction[
                                    artworkOnXYZ[artworkID].openForBid
                                ]
                                .bidsOnArtwork[index]
                                .amount
                        );

                        _resetArtworkAuctionBidParams(artworkID, index);
                    }
                }
            }

            _resetArtworkAuctionParams(artworkID);

            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                ._value = 0;

            artworkOnXYZ[artworkID].openForBid = false;
        } else {
            revert("Invalid Bidding type");
        }

        _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

        emit AuctionCancelled(artworkID, msg.sender);

        return true;
    }

    function encryptData(string memory data) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(data));
    }

    function finalizeTimedAuction(
        uint256 artworkID,
        bool reservePriceReached,
        string memory reservePriceCheck
    ) external returns (bool) {
        _onlyArtworkOwner(artworkID);
        _artworkStatusOpenForBid(artworkID);
        _artworkStatusNotForSale(artworkID);
        _artworkNotPausedForTrade(artworkID);
        _artworkNotPausedForTradeByContractOwner(artworkID);
        _artworkOnTimedAuction(artworkID);
        _artworkAuctionEnded(artworkID);

        require(
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .reserveCheck == keccak256(abi.encodePacked(reservePriceCheck)),
            "You are not valid requestor"
        );

        if (
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .current() == 0
        ) {
            _resetArtworkAuctionParams(artworkID);

            artworkOnXYZ[artworkID].openForBid = false;

            _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

            emit AuctionReverted(artworkID, msg.sender);
        } else if (reservePriceReached) {
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidType = BidTypes.NONE;
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .minimumValidBid = 0;
            artworkOnXYZ[artworkID].price = artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .openBidsOnAuction
                        .current()
                ]
                .amount;
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .expiryAuctionTimestamp = 0;

            // XYZWallet.transfer(artworkOnXYZ[artworkID].price);
            _splitPaymentsBySales(artworkID, artworkOnXYZ[artworkID].price);

            emit TransferredBidToPlatformWallet(
                artworkID,
                address(this),
                XYZWallet,
                artworkOnXYZ[artworkID].price
            );

            artworkOnXYZ[artworkID].ownershipTransferCount.increment();

            artworkOnXYZ[artworkID].owner = artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .openBidsOnAuction
                        .current()
                ]
                .beneficiaryAddress;

            _resetArtworkAuctionBidParams(
                artworkID,
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            );

            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .decrement();

            artworkOnXYZ[artworkID].openForBid = false;

            _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

            emit OwnershipTransferredOfArtwork(
                artworkID,
                artworkOnXYZ[artworkID].ownershipTransferCount.current(),
                artworkOnXYZ[artworkID].owner,
                artworkOnXYZ[artworkID].price,
                artworkOnXYZ[artworkID].owner
            );
        } else {
            _resetArtworkAuctionParams(artworkID);

            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .openBidsOnAuction
                        .current()
                ]
                .beneficiaryAddress
                .transfer(
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .bidsOnArtwork[
                            artworkOnXYZ[artworkID]
                                .openArtworkAuction[
                                    artworkOnXYZ[artworkID].openForBid
                                ]
                                .openBidsOnAuction
                                .current()
                        ]
                        .amount
                );

            emit RefundedBidOnArtwork(
                artworkID,
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .openBidsOnAuction
                            .current()
                    ]
                    .beneficiaryAddress,
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .openBidsOnAuction
                            .current()
                    ]
                    .amount
            );

            _resetArtworkAuctionBidParams(
                artworkID,
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            );

            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .decrement();

            artworkOnXYZ[artworkID].openForBid = false;

            _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

            emit AuctionReverted(artworkID, msg.sender);
        }
        return true;
    }

    function approveAndFinalizeUnlimitedAuction(
        uint256 artworkID,
        uint256 approveBidId
    ) external returns (bool) {
        _onlyArtworkOwner(artworkID);
        _artworkStatusOpenForBid(artworkID);
        _artworkStatusNotForSale(artworkID);
        _artworkNotPausedForTrade(artworkID);
        _artworkNotPausedForTradeByContractOwner(artworkID);
        _artworkOnUnlimitedAuction(artworkID);

        uint256 availableBids = artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .openBidsOnAuction
            .current();

        if (availableBids > 0) {
            require(
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[approveBidId]
                    .bidExpiryTimestamp > block.timestamp,
                "Selected bid is expired"
            );

            require(
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[approveBidId]
                    .amount != 0,
                "Selected bid is 0"
            );

            artworkOnXYZ[artworkID].price = artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[approveBidId]
                .amount;

            artworkOnXYZ[artworkID].owner = artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[approveBidId]
                .beneficiaryAddress;

            _resetArtworkAuctionBidParams(artworkID, approveBidId);

            // XYZWallet.transfer(artworkOnXYZ[artworkID].price);
            _splitPaymentsBySales(artworkID, artworkOnXYZ[artworkID].price);

            emit TransferredBidToPlatformWallet(
                artworkID,
                address(this),
                XYZWallet,
                artworkOnXYZ[artworkID].price
            );

            for (uint256 index = 1; index <= availableBids; index++) {
                if (
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .bidsOnArtwork[index]
                        .amount != 0
                ) {
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .bidsOnArtwork[index]
                        .beneficiaryAddress
                        .transfer(
                            artworkOnXYZ[artworkID]
                                .openArtworkAuction[
                                    artworkOnXYZ[artworkID].openForBid
                                ]
                                .bidsOnArtwork[index]
                                .amount
                        );

                    emit RefundedBidOnArtwork(
                        artworkID,
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .bidsOnArtwork[index]
                            .beneficiaryAddress,
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .bidsOnArtwork[index]
                            .amount
                    );

                    _resetArtworkAuctionBidParams(artworkID, approveBidId);
                }
            }

            artworkOnXYZ[artworkID].ownershipTransferCount.increment();

            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                ._value = 0;

            artworkOnXYZ[artworkID].openForBid = false;

            _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

            emit OwnershipTransferredOfArtwork(
                artworkID,
                artworkOnXYZ[artworkID].ownershipTransferCount.current(),
                artworkOnXYZ[artworkID].owner,
                artworkOnXYZ[artworkID].price,
                artworkOnXYZ[artworkID].owner
            );
        } else {
            _resetArtworkAuctionParams(artworkID);

            artworkOnXYZ[artworkID].openForBid = false;

            _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

            emit AuctionReverted(artworkID, msg.sender);
        }
        return true;
    }

    function claimArtworkAfterTimedAuction(
        uint256 artworkID,
        bool reservePriceReached,
        string memory reservePriceCheck
    ) external returns (bool) {
        _artworkStatusOpenForBid(artworkID);
        _artworkStatusNotForSale(artworkID);
        _artworkNotPausedForTrade(artworkID);
        _artworkNotPausedForTradeByContractOwner(artworkID);
        _artworkAuctionEnded(artworkID);

        require(
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .reserveCheck == keccak256(abi.encodePacked(reservePriceCheck)),
            "You are not valid requestor"
        );

        require(
            msg.sender ==
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .openBidsOnAuction
                            .current()
                    ]
                    .beneficiaryAddress,
            "You are not the highest bidder"
        );

        if (
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .current() == 0
        ) {
            _resetArtworkAuctionParams(artworkID);

            artworkOnXYZ[artworkID].openForBid = false;

            _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

            emit AuctionReverted(artworkID, msg.sender);
        } else if (reservePriceReached) {
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidType = BidTypes.NONE;
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .minimumValidBid = 0;
            artworkOnXYZ[artworkID].price = artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .openBidsOnAuction
                        .current()
                ]
                .amount;
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .expiryAuctionTimestamp = 0;

            // XYZWallet.transfer(artworkOnXYZ[artworkID].price);
            _splitPaymentsBySales(artworkID, artworkOnXYZ[artworkID].price);

            emit TransferredBidToPlatformWallet(
                artworkID,
                address(this),
                XYZWallet,
                artworkOnXYZ[artworkID].price
            );

            artworkOnXYZ[artworkID].ownershipTransferCount.increment();

            artworkOnXYZ[artworkID].owner = artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .openBidsOnAuction
                        .current()
                ]
                .beneficiaryAddress;

            _resetArtworkAuctionBidParams(
                artworkID,
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            );

            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .decrement();

            artworkOnXYZ[artworkID].openForBid = false;

            _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

            emit OwnershipTransferredOfArtwork(
                artworkID,
                artworkOnXYZ[artworkID].ownershipTransferCount.current(),
                artworkOnXYZ[artworkID].owner,
                artworkOnXYZ[artworkID].price,
                artworkOnXYZ[artworkID].owner
            );
        } else {
            _resetArtworkAuctionParams(artworkID);

            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .openBidsOnAuction
                        .current()
                ]
                .beneficiaryAddress
                .transfer(
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .bidsOnArtwork[
                            artworkOnXYZ[artworkID]
                                .openArtworkAuction[
                                    artworkOnXYZ[artworkID].openForBid
                                ]
                                .openBidsOnAuction
                                .current()
                        ]
                        .amount
                );

            emit RefundedBidOnArtwork(
                artworkID,
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .openBidsOnAuction
                            .current()
                    ]
                    .beneficiaryAddress,
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .openBidsOnAuction
                            .current()
                    ]
                    .amount
            );

            _resetArtworkAuctionBidParams(
                artworkID,
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            );

            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .decrement();

            artworkOnXYZ[artworkID].openForBid = false;

            _transfer(address(this), artworkOnXYZ[artworkID].owner, artworkID);

            emit AuctionReverted(artworkID, msg.sender);
        }
        return true;
    }

    function claimBidOnUmlimitedAuctionAfterExpiry(
        uint256 artworkID,
        uint256 claimBidID
    ) external returns (bool) {
        _artworkStatusOpenForBid(artworkID);
        _artworkStatusNotForSale(artworkID);
        _notArtworkOwner(artworkID);
        require(
            msg.sender ==
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[claimBidID]
                    .beneficiaryAddress,
            "You are not the bidder"
        );

        require(
            block.timestamp >
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[claimBidID]
                    .bidExpiryTimestamp,
            "Your bid is not expired"
        );

        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[claimBidID]
            .beneficiaryAddress
            .transfer(
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[claimBidID]
                    .amount
            );

        emit ClaimedBidOnUnlimitedAuction(
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[claimBidID]
                .beneficiaryAddress,
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[claimBidID]
                .amount,
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[claimBidID]
                .bidExpiryTimestamp
        );

        _resetArtworkAuctionBidParams(artworkID, claimBidID);

        return true;
    }

    function bidOnTimedAuction(uint256 artworkID)
        external
        payable
        returns (bool)
    {
        _artworkStatusOpenForBid(artworkID);
        _notArtworkOwner(artworkID);
        _artworkNotPausedForTrade(artworkID);
        _artworkNotPausedForTradeByContractOwner(artworkID);
        _artworkAuctionNotEnded(artworkID);
        _isValidBidAuction(artworkID);

        require(
            msg.value >
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .openBidsOnAuction
                            .current()
                    ]
                    .amount,
            "Bid less than other available bid"
        );

        if (
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .current() == 1
        ) {
            refundExistingOffer(artworkID);
        } else {
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .openBidsOnAuction
                .increment();
        }

        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            ]
            .beneficiaryAddress = payable(msg.sender);
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            ]
            .amount = msg.value;

        emit NewBidOnArtwork(artworkID, msg.sender, msg.value);

        return true;
    }

    function bidOnUnlimitedAuction(uint256 artworkID, uint256 bidExpiryTime)
        external
        payable
        returns (bool)
    {
        _artworkStatusOpenForBid(artworkID);
        _notArtworkOwner(artworkID);
        _artworkNotPausedForTrade(artworkID);
        _artworkNotPausedForTradeByContractOwner(artworkID);
        _artworkOnUnlimitedAuction(artworkID);
        _isValidBidAuction(artworkID);

        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .openBidsOnAuction
            .increment();

        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            ]
            .beneficiaryAddress = payable(msg.sender);
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            ]
            .amount = msg.value;
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            ]
            .bidExpiryTimestamp = bidExpiryTime;

        emit NewBidOnArtwork(artworkID, msg.sender, msg.value);

        return true;
    }

    function refundExistingOffer(uint256 artworkID) internal returns (bool) {
        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .bidsOnArtwork[
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .openBidsOnAuction
                    .current()
            ]
            .beneficiaryAddress
            .transfer(
                artworkOnXYZ[artworkID]
                    .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                    .bidsOnArtwork[
                        artworkOnXYZ[artworkID]
                            .openArtworkAuction[
                                artworkOnXYZ[artworkID].openForBid
                            ]
                            .openBidsOnAuction
                            .current()
                    ]
                    .amount
            );

        emit RefundedBidOnArtwork(
            artworkID,
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .openBidsOnAuction
                        .current()
                ]
                .beneficiaryAddress,
            artworkOnXYZ[artworkID]
                .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                .bidsOnArtwork[
                    artworkOnXYZ[artworkID]
                        .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
                        .openBidsOnAuction
                        .current()
                ]
                .amount
        );
        return true;
    }

    function updateAuctionMinimumBid(uint256 artworkID, uint256 minimumValidBid)
        external
        whenNotPaused
        returns (bool)
    {
        _onlyArtworkOwner(artworkID);
        _artworkStatusOpenForBid(artworkID);

        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .minimumValidBid = minimumValidBid;

        emit UpdatedAuctionMinimumBid(artworkID, minimumValidBid, msg.sender);
        return true;
    }

    function updateArtworkExpiryTimestamp(
        uint256 artworkID,
        uint256 expiryTimestamp
    ) external whenNotPaused returns (bool) {
        _onlyArtworkOwner(artworkID);
        _artworkStatusOpenForBid(artworkID);

        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .expiryAuctionTimestamp = expiryTimestamp;

        emit UpdatedAuctionExpiryTimestamp(
            artworkID,
            expiryTimestamp,
            msg.sender
        );
        return true;
    }

    function updateArtworkReservePrice(uint256 artworkID, bytes32 reservePrice)
        external
        whenNotPaused
        returns (bool)
    {
        _onlyArtworkOwner(artworkID);
        _artworkStatusOpenForBid(artworkID);

        artworkOnXYZ[artworkID]
            .openArtworkAuction[artworkOnXYZ[artworkID].openForBid]
            .reserveCheck = reservePrice;

        emit UpdatedAuctionReservePrice(artworkID, reservePrice, msg.sender);
        return true;
    }
}