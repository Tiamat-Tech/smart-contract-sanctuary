// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Decimal} from "./Decimal.sol";
import {Media} from "./Media.sol";
import {IMarket} from "./interfaces/IMarket.sol";

/**
 * @title A Market for pieces of media
 * @notice This contract contains all of the market logic for Media
 */
contract Market is IMarket {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* *******
     * Globals
     * *******
     */
    // Address of the media contract that can call this market
    address public mediaContract;

    // Deployment Address
    address private _owner;

    // Mapping from token to mapping from bidder to bid
    mapping(uint256 => mapping(address => Bid)) private _tokenBidders;

    // Mapping from token to the current ask for the token
    mapping(uint256 => uint256) private _tokenAsks;

    /* *********
     * Modifiers
     * *********
     */

    /**
     * @notice require that the msg.sender is the configured media contract
     */
    modifier onlyMediaCaller() {
        require(mediaContract == msg.sender, "Market: Only media contract");
        _;
    }

    /* ****************
     * View Functions
     * ****************
     */
    function bidForTokenBidder(uint256 tokenId, address bidder)
        external
        view
        override
        returns (Bid memory)
    {
        return _tokenBidders[tokenId][bidder];
    }

    function currentAskForToken(uint256 tokenId)
        external
        view
        override
        returns (uint256)
    {
        return _tokenAsks[tokenId];
    }

    function isValidBid(uint256 tokenId, uint256 bidAmount)
        public
        pure
        override
        returns (bool)
    {
        return bidAmount != 0;
    }

    /* ****************
     * Public Functions
     * ****************
     */

    constructor() {
        _owner = msg.sender;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @notice Sets the media contract address. This address is the only permitted address that
     * can call the mutable functions. This method can only be called once.
     */
    function configure(address mediaContractAddress) external override {
        require(msg.sender == _owner, "Market: Only owner");
        require(mediaContract == address(0), "Market: Already configured");
        require(
            mediaContractAddress != address(0),
            "Market: cannot set media contract as zero address"
        );

        mediaContract = mediaContractAddress;
    }

    function setAsk(uint256 tokenId, uint256 ask)
        public
        override
        onlyMediaCaller
    {
        require(isValidBid(tokenId, ask), "Market: Ask invalid");
        _tokenAsks[tokenId] = ask;
        emit AskCreated(tokenId, ask);
    }

    /**
     * @notice removes an ask for a token and emits an AskRemoved event
     */
    function removeAsk(uint256 tokenId) external override onlyMediaCaller {
        emit AskRemoved(tokenId, _tokenAsks[tokenId]);
        delete _tokenAsks[tokenId];
    }

    function setBid(uint256 tokenId, Bid calldata bid)
        public
        payable
        override
        onlyMediaCaller
    {
        require(bid.bidder != address(0), "Market: bidder cannot be 0 address");
        require(bid.amount != 0, "Market: cannot bid amount of 0");
        require(bid.amount == msg.value, "Market: invalid amount");
        require(
            bid.recipient != address(0),
            "Market: bid recipient cannot be 0 address"
        );

        Bid storage existingBid = _tokenBidders[tokenId][bid.bidder];

        // If there is an existing bid, refund it before continuing
        if (existingBid.amount > 0) {
            removeBid(tokenId, bid.bidder);
        }

        _tokenBidders[tokenId][bid.bidder] = Bid(
            msg.value,
            bid.bidder,
            bid.recipient
        );
        emit BidCreated(tokenId, bid);

        // If a bid meets the criteria for an ask, automatically accept the bid.
        // If no ask is set or the bid does not meet the requirements, ignore.
        if (_tokenAsks[tokenId] > 0 && bid.amount >= _tokenAsks[tokenId]) {
            // Finalize exchange
            _finalizeNFTTransfer(tokenId, bid.bidder);
        }
    }

    /**
     * @notice Removes the bid on a particular media for a bidder. The bid amount
     * is transferred from this contract to the bidder, if they have a bid placed.
     */
    function removeBid(uint256 tokenId, address bidder)
        public
        override
        onlyMediaCaller
    {
        Bid storage bid = _tokenBidders[tokenId][bidder];
        uint256 bidAmount = bid.amount;

        require(bid.amount > 0, "Market: cannot remove bid amount of 0");

        emit BidRemoved(tokenId, bid);
        delete _tokenBidders[tokenId][bidder];
        require(payable(bidder).send(bidAmount), "Market: failed to refund");
    }

    function acceptBid(uint256 tokenId, Bid calldata expectedBid)
        external
        override
        onlyMediaCaller
    {
        Bid memory bid = _tokenBidders[tokenId][expectedBid.bidder];
        require(bid.amount > 0, "Market: cannot accept bid of 0");
        require(
            bid.amount == expectedBid.amount &&
                bid.recipient == expectedBid.recipient,
            "Market: Unexpected bid found."
        );
        require(
            isValidBid(tokenId, bid.amount),
            "Market: Bid invalid for share splitting"
        );

        _finalizeNFTTransfer(tokenId, bid.bidder);
    }

    /**
     * @notice Given a token ID and a bidder, this method transfers the value of
     * the bid. It also transfers the ownership of the media
     * to the bid recipient. Finally, it removes the accepted bid and the current ask.
     */
    function _finalizeNFTTransfer(uint256 tokenId, address bidder) private {
        Bid memory bid = _tokenBidders[tokenId][bidder];

        require(
            payable(IERC721(mediaContract).ownerOf(tokenId)).send(bid.amount)
        );

        // Transfer media to bid recipient
        Media(mediaContract).auctionTransfer(tokenId, bid.recipient);

        // Remove the accepted bid
        delete _tokenBidders[tokenId][bidder];

        // emit BidShareUpdated(tokenId, bidShares);
        emit BidFinalized(tokenId, bid);
    }
}