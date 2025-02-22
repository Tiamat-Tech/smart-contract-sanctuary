//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Holder.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IAuctionFactory.sol";

contract AuctionFactory is IAuctionFactory, ERC721Holder {
    using SafeMath for uint256;

    uint256 public totalAuctions;
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
        uint256 numberOfSlots,
        uint256 startBlockNumber,
        uint256 endBlockNumber,
        uint256 resetTimer,
        bool supportsWhitelist,
        uint256 time
    );

    event LogBidSubmitted(
        address sender,
        uint256 auctionId,
        uint256 currentBid,
        uint256 totalBid,
        uint256 time
    );

    event LogWithdraw(
        address recipient,
        uint256 auction,
        uint256 amount,
        uint256 time
    );

    modifier onlyExistingAuction(uint256 _auctionId) {
        require(
            _auctionId > 0 && _auctionId <= totalAuctions,
            "Invalid Auction"
        );
        _;
    }

    constructor() {}

    function createAuction(
        uint256 _startBlockNumber,
        uint256 _endBlockNumber,
        uint256 _resetTimer,
        uint256 _numberOfSlots,
        bool _supportsWhitelist,
        address _bidToken
    ) external override returns (uint256) {
        uint256 blockNumber = block.number;
        require(
            blockNumber <= _startBlockNumber,
            "Auction cannot begin before the current block"
        );
        require(
            _startBlockNumber < _endBlockNumber,
            "Auction cannot end before it is launched"
        );
        uint256 _auctionId = totalAuctions.add(1);

        auctions[_auctionId].auctionOwner = msg.sender;
        auctions[_auctionId].startBlockNumber = _startBlockNumber;
        auctions[_auctionId].endBlockNumber = _endBlockNumber;
        auctions[_auctionId].resetTimer = _resetTimer;
        auctions[_auctionId].numberOfSlots = _numberOfSlots;
        auctions[_auctionId].supportsWhitelist = _supportsWhitelist;
        auctions[_auctionId].bidToken = _bidToken;

        totalAuctions = totalAuctions.add(1);

        emit LogAuctionCreated(
            _auctionId,
            msg.sender,
            _numberOfSlots,
            _startBlockNumber,
            _endBlockNumber,
            _resetTimer,
            _supportsWhitelist,
            block.timestamp
        );

        return _auctionId;
    }

    function depositERC721(
        uint256 _auctionId,
        uint256 _slotIndex,
        uint256 _tokenId,
        address _tokenAddress
    ) external override onlyExistingAuction(_auctionId) returns (bool) {
        address _depositor = msg.sender;

        require(
            _tokenAddress != address(0),
            "Zero address was provided for token address"
        );

        if (auctions[_auctionId].supportsWhitelist) {
            require(
                auctions[_auctionId].whitelistAddresses[_depositor] == true,
                "You are not allowed to deposit in this auction"
            );
        }

        require(
            auctions[_auctionId].numberOfSlots >= _slotIndex,
            "You are trying to deposit to a non-existing slot"
        );

        DepositedERC721 memory item =
            DepositedERC721({
                auctionId: _auctionId,
                slotIndex: _slotIndex,
                tokenId: _tokenId,
                tokenAddress: _tokenAddress,
                depositor: _depositor
            });

        auctions[_auctionId].slots[_slotIndex].auctionId = _auctionId;
        auctions[_auctionId].slots[_slotIndex].slotIndex = _slotIndex;
        auctions[_auctionId].slots[_slotIndex].nfts.push(item);

        IERC721(_tokenAddress).safeTransferFrom(
            _depositor,
            address(this),
            _tokenId
        );

        emit LogERC721Deposit(
            _depositor,
            _tokenAddress,
            _tokenId,
            _auctionId,
            _slotIndex,
            block.timestamp
        );

        return true;
    }

    function bid(uint256 _auctionId)
        external
        payable
        override
        onlyExistingAuction(_auctionId)
        returns (bool)
    {
        uint256 _bid = msg.value;
        address _bidder = msg.sender;

        require(_bid > 0, "Bid amount must be higher than 0");
        require(
            auctions[_auctionId].bidToken == address(0),
            "This auction does not accept ETH for bidding"
        );

        Auction storage auction = auctions[_auctionId];
        auction.balanceOf[_bidder] = auction.balanceOf[_bidder].add(_bid);

        emit LogBidSubmitted(
            _bidder,
            _auctionId,
            _bid,
            auction.balanceOf[_bidder],
            block.timestamp
        );

        return true;
    }

    function bid(uint256 _auctionId, uint256 _amount)
        external
        override
        onlyExistingAuction(_auctionId)
        returns (bool)
    {
        uint256 _bid = _amount;
        address _bidder = msg.sender;

        require(_bid > 0, "Bid amount must be higher than 0");
        require(
            auctions[_auctionId].bidToken != address(0),
            "No token contract address provided"
        );

        IERC20 bidToken = IERC20(auctions[_auctionId].bidToken);
        uint256 allowance = bidToken.allowance(msg.sender, address(this));
        require(allowance >= _bid, "Token allowance too small");

        Auction storage auction = auctions[_auctionId];
        auction.balanceOf[_bidder] = auction.balanceOf[_bidder].add(_bid);

        bidToken.transferFrom(_bidder, address(this), _bid);

        emit LogBidSubmitted(
            _bidder,
            _auctionId,
            _bid,
            auction.balanceOf[_bidder],
            block.timestamp
        );

        return true;
    }

    function finalize(uint256 _auctionId)
        external
        override
        onlyExistingAuction(_auctionId)
        returns (bool)
    {}

    function withdrawBid(uint256 _auctionId)
        external
        override
        onlyExistingAuction(_auctionId)
        returns (bool)
    {
        address payable _recipient = msg.sender;
        Auction storage auction = auctions[_auctionId];

        require(auction.balanceOf[_recipient] > 0, "You have 0 deposited");

        uint256 amountToWithdraw = auction.balanceOf[_recipient];

        auction.balanceOf[_recipient] = 0;

        _recipient.transfer(amountToWithdraw);

        emit LogWithdraw(
            _recipient,
            _auctionId,
            amountToWithdraw,
            block.timestamp
        );

        return true;
    }

    function matchBidToSlot(uint256 _auctionId, uint256 _amount)
        external
        override
        onlyExistingAuction(_auctionId)
        returns (uint256)
    {}

    function cancelAuction(uint256 _auctionId)
        external
        override
        onlyExistingAuction(_auctionId)
        returns (bool)
    {}

    function getSlot(uint256 _auctionId, uint256 _slotIndex)
        external
        view
        override
        onlyExistingAuction(_auctionId)
        returns (Slot memory)
    {
        return auctions[_auctionId].slots[_slotIndex];
    }

    function getDeposited(uint256 _auctionId, uint256 _slotIndex)
        external
        view
        override
        onlyExistingAuction(_auctionId)
        returns (DepositedERC721[] memory)
    {
        return auctions[_auctionId].slots[_slotIndex].nfts;
    }

    function getBidderBalance(uint256 _auctionId, address _bidder)
        external
        view
        override
        onlyExistingAuction(_auctionId)
        returns (uint256)
    {
        return auctions[_auctionId].balanceOf[_bidder];
    }
}