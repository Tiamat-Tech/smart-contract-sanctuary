// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {Decimal} from "./Decimal.sol";
import {Media} from "./Media.sol";
import {IMarket} from "./IMarket.sol";

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

    // // Mapping from token to the bid shares for the token
    mapping(uint256 => BidShares) private _bidShares;

    // Mapping from token to the current ask for the token
    mapping(uint256 => uint256) private _tokenAsks;

    // Mapping tokenId to the sold items list
    mapping(uint256 => bool) private _soldTokenList;

    struct TokenAskInfo {
        uint256 tokenId;
        uint256 askValue; 
        address tokenOwner;
    }

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
        returns (uint256 )
    {
        return _tokenAsks[tokenId];
    }

    function bidSharesForToken(uint256 tokenId)
        public
        view
        override
        returns (BidShares memory)
    {
        return _bidShares[tokenId];
    }

    

    constructor() public {
        _owner = msg.sender;
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

    

    /**
     * @notice Sets the ask on a particular media. If the ask cannot be evenly split into the media's
     * bid shares, this reverts.
     */
    function setAsk(uint256 tokenId, uint256  ask)
        public
        override
        onlyMediaCaller
    {
        require(
            isValidBid(tokenId, ask),
            "Market: Ask invalid for share splitting"
        );

        _tokenAsks[tokenId] = ask;
        emit AskCreated(tokenId, ask);
    }

    // get All token information

    function getAllTokens() public view returns(TokenAskInfo[] memory) 
    {
        uint256 tokenCount = Media(mediaContract).getTokenCount();
        TokenAskInfo[] memory result = new TokenAskInfo[](tokenCount);        
        for (uint i = 0; i < tokenCount; i++) {
            try IERC721(mediaContract).ownerOf(i)
            {
                result[i] = TokenAskInfo ({
                    tokenId : i, 
                    askValue : _tokenAsks[i], 
                    tokenOwner : IERC721(mediaContract).ownerOf(i)
                });
            } catch {

            }
        }
        return result;
    }


    /**
     * @notice removes an ask for a token and emits an AskRemoved event
     */
    function removeAsk(uint256 tokenId) external override onlyMediaCaller {
        emit AskRemoved(tokenId, _tokenAsks[tokenId]);
        delete _tokenAsks[tokenId];
    }

    /**
     * @notice Sets the bid on a particular media for a bidder. The token being used to bid
     * is transferred from the spender to this contract to be held until removed or accepted.
     * If another bid already exists for the bidder, it is refunded.
     */
    function setBid(
        uint256 tokenId,
        Bid memory bid
    ) payable public override onlyMediaCaller {
        BidShares memory bidShares = _bidShares[tokenId];
        require(
            bidShares.creator.value.add(bid.sellOnShare.value) <=
                uint256(100).mul(Decimal.BASE),
            "Market: Sell on fee invalid for share splitting"
        );
        require(bid.bidder != address(0), "Market: bidder cannot be 0 address");
        require(bid.amount != 0, "Market: cannot bid amount of 0");
        
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
            // afterBalance.sub(beforeBalance),
            msg.value, 
            // bid.currency,
            bid.bidder,
            bid.recipient,
            bid.sellOnShare
        );
        emit BidCreated(tokenId, bid);

        // If a bid meets the criteria for an ask, automatically accept the bid.
        // If no ask is set or the bid does not meet the requirements, ignore.
        if (
            // _tokenAsks[tokenId].currency != address(0) &&
            // bid.currency == _tokenAsks[tokenId].currency &&
            _tokenAsks[tokenId]> 0 && 
            bid.amount >= _tokenAsks[tokenId]
        ) {
            // Finalize exchange
            _finalizeNFTTransfer(tokenId, bid.bidder);
        }
    }

    function isValidBid(uint256 tokenId, uint256 bidAmount)
        public
        view
        override
        returns (bool)
    {
        BidShares memory bidShares = bidSharesForToken(tokenId);
        require(
            isValidBidShares(bidShares),
            "Market: Invalid bid shares for token"
        );
        return        bidAmount != 0;
    }

    /**
     * @notice Validates that the provided bid shares sum to 100
     */
    function isValidBidShares(BidShares memory bidShares)
        public
        pure
        override
        returns (bool)
    {
        return
            bidShares.creator.value.add(bidShares.owner.value).add(
                bidShares.prevOwner.value
            ) == uint256(100).mul(Decimal.BASE);
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
        // address bidCurrency = bid.currency;
        require(bid.amount > 0, "Market: cannot remove bid amount of 0");

        // IERC20 token = IERC20(bidCurrency);

        emit BidRemoved(tokenId, bid);
        delete _tokenBidders[tokenId][bidder];
        payable(bidder).transfer(bidAmount);
        // token.safeTransfer(bidder, bidAmount);
    }

    /**
     * @notice Accepts a bid from a particular bidder. Can only be called by the media contract.
     * See {_finalizeNFTTransfer}
     * Provided bid must match a bid in storage. This is to prevent a race condition
     * where a bid may change while the acceptBid call is in transit.
     * A bid cannot be accepted if it cannot be split equally into its shareholders.
     * This should only revert in rare instances (example, a low bid with a zero-decimal token),
     * but is necessary to ensure fairness to all shareholders.
     */
    function acceptBid(uint256 tokenId, Bid calldata expectedBid)
        external
        override
        onlyMediaCaller
    {
        Bid memory bid = _tokenBidders[tokenId][expectedBid.bidder];
        require(bid.amount > 0, "Market: cannot accept bid of 0");
        require(
            bid.amount == expectedBid.amount &&
                // bid.currency == expectedBid.currency &&
                bid.sellOnShare.value == expectedBid.sellOnShare.value &&
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
     * @notice return a % of the specified amount. This function is used to split a bid into shares
     * for a media's shareholders.
     */
    function splitShare(Decimal.D256 memory sharePercentage, uint256 amount)
        public
        pure
        override
        returns (uint256)
    {
        return Decimal.mul(amount, sharePercentage).div(100);
    }

    /**
     * @notice Sets bid shares for a particular tokenId. These bid shares must
     * sum to 100.
     */
    function setBidShares(uint256 tokenId, BidShares memory bidShares)
        public
        override
        onlyMediaCaller
    {
        require(
            isValidBidShares(bidShares),
            "Market: Invalid bid shares, must sum to 100"
        );
        _bidShares[tokenId] = bidShares;
        emit BidShareUpdated(tokenId, bidShares);
    }

    /**
     * @notice Given a token ID and a bidder, this method transfers the value of
     * the bid to the shareholders. It also transfers the ownership of the media
     * to the bid recipient. Finally, it removes the accepted bid and the current ask.
     */
    function _finalizeNFTTransfer(uint256 tokenId, address bidder) private {
        Bid memory bid = _tokenBidders[tokenId][bidder];
        BidShares storage bidShares = _bidShares[tokenId];

        // IERC20 token = IERC20(bid.currency);

        uint256  ownerAmount;
        uint256  creatorAmount;

        ownerAmount = splitShare(bidShares.owner, bid.amount);
        creatorAmount = splitShare(bidShares.creator, bid.amount);

        // pay bidshares here
        if(_soldTokenList[tokenId])   // if this is the secondary sale
        {
            payable(IERC721(mediaContract).ownerOf(tokenId)).transfer(ownerAmount);
        } else {         // if this is primary sale
            payable(address(0x3c739BEa9af7c33045b6E26655E0E6Fa04d18f21)).transfer(ownerAmount);
        }

        payable(Media(mediaContract).tokenCreators(tokenId)).transfer(creatorAmount);

        // Transfer media to bid recipient
        Media(mediaContract).auctionTransfer(tokenId, bid.recipient);

        // Calculate the bid share for the new owner,
        // equal to 100 - creatorShare - sellOnShare
        bidShares.owner = Decimal.D256(
            uint256(100)
                .mul(Decimal.BASE)
                .sub(_bidShares[tokenId].creator.value)
                .sub(bid.sellOnShare.value)
        );
        // Set the previous owner share to the accepted bid's sell-on fee
        bidShares.prevOwner = bid.sellOnShare;

        // Remove the accepted bid
        delete _tokenBidders[tokenId][bidder];

        emit BidShareUpdated(tokenId, bidShares);
        emit BidFinalized(tokenId, bid);

        // Add sold tokenId to the _soldTokenList
        if(!_soldTokenList[tokenId])
           _soldTokenList[tokenId] = true;
    }
}