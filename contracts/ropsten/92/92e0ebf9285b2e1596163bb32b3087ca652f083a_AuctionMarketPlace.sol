// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import './utils/WETH.sol';


import './NFTation.sol';

contract AuctionMarketPlace is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using SafeMath for uint256;
    using SafeMath for uint8;
    using Counters for Counters.Counter;


    // +STORAGE -------------------------------------------------
    NFTation                     private NFTationContract;
    uint256                     private marketPlaceShare;

    mapping(uint256 => Auction) public  tokenIdToAuction;
    Counters.Counter            private auctionCounter;

    mapping(address => bool)    private validERC20TokenContracts;
    // -STORAGE -------------------------------------------------

    // +STRUCTS -------------------------------------------------
    struct Bid {
        uint16 id;
        uint256 amount;
        uint256 submittedTime;
        address sender;
    }

    struct Auction {
        uint256 id;
        uint256 duration;
        uint256 startedAt;
        uint256 minBidPrice;
        uint256 tokenId;
        address seller;
        uint16 numOfBids;
        uint16 numOfCanceledBids; 
        mapping(address => Bid) bids;

        address[] bidders;
        mapping(address => bool) biddersIndex;

        address tokenContract;

        bool isActive;
        address winner;
        bool finished;
    }
    // -STRUCTS -------------------------------------------------

    // +EVENTS --------------------------------------------------
    event BidSubmitted(uint256 auctionId, uint256 tokenId, address sender, uint256 submittedTime, uint256 amount, uint64 bidId);
    event BidCanceled(address sender, uint256 tokenId, uint64 bidId);
    event AuctionCreated(uint256 auctionId, uint256 tokenId, uint256 startedAt, uint256 duration, uint256 minBidPrice, address tokenContract);
    event SuccessfulWithdrawBid(uint256 tokenId, uint256 withdrawAmount, address winner);
    event AuctionCancelled(uint256 tokenId, uint256 auctionId);
    event ERC20TokenAddressAdded(address contractAddress);
    event ERC20TokenAddressRemoved(address contractAddress);
    event BidAccepted(uint256 auctionId, uint256 tokenId, address winner, uint256 bidId, uint256 amount);
    event AuctionRoyaltyPurchased(uint256 auctionId, uint256 tokenId, address tokenCreator, uint256 amount);
    event AuctionPurchased(uint256 auctionId, uint256 tokenId, address seller, uint256 amount);
    event AuctionMinBidPriceChanged(uint256 auctionId, uint256 tokenId, uint256 newMinBidPrice);

    // -EVENTS --------------------------------------------------

    // +MODIFIERS -----------------------------------------------
    modifier onAuction(uint256 _tokenId) {
        require(tokenIdToAuction[_tokenId].startedAt > 0, "This item is not on auction");
        _;
    }

    modifier activeAuction(uint256 _tokenId) {
        Auction storage _auction = tokenIdToAuction[_tokenId];
        require(_auction.isActive, "Auction is not active");
        (bool status, uint256 x) = SafeMath.trySub(block.timestamp, _auction.startedAt);
        require(status && x < _auction.duration ,"The time for this auction is expired");
        require(block.timestamp > _auction.startedAt, "Auction hasn't been started yet");
        _;
    }
    // -MODIFIERS -----------------------------------------------

    constructor() {}

    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function initToken(address _NFTationContract,uint8 marketPlaceSharePercentage) public onlyOwner {
        NFTationContract = NFTation(_NFTationContract);
        marketPlaceShare = marketPlaceSharePercentage;
    }

    function addERC20TokenContractAddress(address _contract) public onlyOwner {
        validERC20TokenContracts[_contract] = true;
        emit ERC20TokenAddressAdded(_contract);
    }

    function removeERC20TokenContractAddress(address _contract) public onlyOwner {
        validERC20TokenContracts[_contract] = false;
        emit ERC20TokenAddressRemoved(_contract);
    }

    function isValidERC20Contract(address _contract) internal view returns(bool) {
        return validERC20TokenContracts[_contract];
    } 
    
    function simpleCreateAuction(
        uint256 _tokenId,
        uint256 _minBidPrice,
        uint256 _duration,
        address _ERC20TokenAddress
    ) external {
        createAuction(
            _tokenId,
            _minBidPrice,
            block.timestamp,
            _duration,
            _ERC20TokenAddress
        );
    }

    function createAuction(
        uint256 _tokenId,
        uint256 _minBidPrice,
        uint256 _startAt,
        uint256 _duration,
        address _ERC20TokenAddress
    ) public {
        //TODO using safemath
        //TODO validate duration(min and max)
        require(NFTationContract.ownerOf(_tokenId) == msg.sender, "this item is not in possition of this address");
        require(_startAt >= block.timestamp, "invalid start time");
        require(isValidERC20Contract(_ERC20TokenAddress), "invalid ERC20 contract address");

        NFTationContract.transferFrom(msg.sender, address(this), _tokenId);

        auctionCounter.increment();

        Auction storage auction = tokenIdToAuction[_tokenId];
        auction.id = auctionCounter.current();
        auction.duration = _duration;
        auction.startedAt = _startAt;
        auction.minBidPrice = _minBidPrice;
        auction.tokenId = _tokenId;
        auction.seller = msg.sender;
        auction.isActive = true;
        auction.tokenContract = _ERC20TokenAddress;

        emit AuctionCreated(
            auctionCounter.current(),
            _tokenId,
            _startAt,
            tokenIdToAuction[_tokenId].duration,
            tokenIdToAuction[_tokenId].minBidPrice,
            _ERC20TokenAddress
        );
    }

    function changeAuctionMinBidPrice(uint256 _tokenId, uint256 _newMinBidPrice) external {
        Auction storage _auction = tokenIdToAuction[_tokenId];
        require(_auction.isActive, "auction does not exists");
        require(_auction.numOfBids == 0, 'auction has bid');
        require(msg.sender == _auction.seller, 'only seller can accept bid');

        _auction.minBidPrice = _newMinBidPrice;

        emit AuctionMinBidPriceChanged(_auction.id, _tokenId, _newMinBidPrice);   
    }

    function acceptBid(uint256 _tokenId, address _winner) external {
        Auction storage _auction = tokenIdToAuction[_tokenId];
        require(_auction.isActive, "auction does not exists");
        require(msg.sender == _auction.seller, 'only seller can accept bid');
        require(_auction.biddersIndex[_winner], 'bid not exists');

        ERC20 _ERC20 = ERC20(_auction.tokenContract);

        uint256 price = _auction.bids[_winner].amount;

        uint256 marketPlaceShareAmount = marketPlaceShare.mul(price).div(100);
        uint256 remaining = price.sub(marketPlaceShareAmount);

        (address tokenCreator, uint256 creatorShare) = NFTationContract.royaltyInfo(_tokenId, remaining);
        uint256 sellerShare = remaining.sub(creatorShare);

        require(_ERC20.transferFrom(_winner, tokenCreator, creatorShare));
        emit AuctionRoyaltyPurchased(_auction.id, _tokenId, tokenCreator, creatorShare);

        require(_ERC20.transferFrom(_winner, _auction.seller, sellerShare));
        emit AuctionPurchased(_auction.id, _tokenId, _auction.seller, sellerShare);

        require(_ERC20.transferFrom(_winner, owner(), marketPlaceShareAmount));

        NFTationContract.transferFrom(address(this), _winner, _tokenId);

        _auction.finished = true;
        _auction.isActive = false;
        _auction.winner = _winner;

        emit BidAccepted(_auction.id, _tokenId, _winner, _auction.bids[_winner].id, _auction.bids[_winner].amount);
    }

    function cancelAuction(uint256 _tokenId) external {
        Auction storage _auction = tokenIdToAuction[_tokenId];
        require(_auction.isActive, "auction does not exists");
        require(_auction.seller == msg.sender, "This item is not in possition of this address");
        NFTationContract.transferFrom(address(this), _auction.seller, _tokenId);
        delete tokenIdToAuction[_tokenId];
        emit AuctionCancelled(_tokenId, _auction.id);
    }

    function placeBid(uint256 _tokenId, uint256 _amount) external activeAuction(_tokenId)
                                                                  onAuction(_tokenId) {

        Auction storage _auction = tokenIdToAuction[_tokenId];
        ERC20 _ERC20 = ERC20(_auction.tokenContract);
        
        require(msg.sender != _auction.seller , 'seller can not bid on its owned auction');
        require(_amount >= _auction.minBidPrice, 'can not bid less than minimum bid price');
        require(_ERC20.balanceOf(msg.sender) >= _amount , 'con not place bid less than account balance');
        require(_ERC20.allowance(msg.sender, address(this)) >= _amount , 'should approve contract');

        if (_auction.biddersIndex[msg.sender]) {
            emit BidCanceled(msg.sender, _tokenId, _auction.bids[msg.sender].id);
        }

        _auction.numOfBids ++;
        uint16 _bidId = _auction.numOfBids;
        Bid memory bid = Bid(_bidId, _amount, uint64(block.timestamp), payable(msg.sender));
        _auction.bids[msg.sender] = bid;

        if (!_auction.biddersIndex[msg.sender]) {
            _auction.bidders.push(msg.sender);
            _auction.biddersIndex[msg.sender] = true;
        }
        
        emit BidSubmitted(_auction.id, _tokenId, msg.sender , bid.submittedTime, _amount, _bidId);
    }

    function cancelBid(uint256 _tokenId) external activeAuction(_tokenId)
                                                  onAuction(_tokenId) {

        Auction storage _auction = tokenIdToAuction[_tokenId];

        require(_auction.biddersIndex[msg.sender], 'no bid exists');

        uint16 _bidId = _auction.bids[msg.sender].id;
        _auction.biddersIndex[msg.sender] = false;

        _auction.numOfCanceledBids ++;

        uint256 targetBidderIndex;
        for (uint256 i = 0; i < _auction.bidders.length; i++) {
            if(_auction.bidders[i] == msg.sender) {
                targetBidderIndex = i;
                break;
            }
        }

        address tmp = _auction.bidders[targetBidderIndex];
        _auction.bidders[targetBidderIndex] = _auction.bidders[_auction.bidders.length - 1];
        _auction.bidders[_auction.bidders.length - 1] = tmp;
        _auction.bidders.pop();

        delete _auction.bids[msg.sender];

        emit BidCanceled(msg.sender, _tokenId, _bidId);
    }

    function getBidAmount(uint256 _tokenId, address _targetAddress) public view returns(uint256) {
        return tokenIdToAuction[_tokenId].bids[_targetAddress].amount;
    }

    function auctionHasBid(uint256 _tokenId) public view returns(bool) {
        return tokenIdToAuction[_tokenId].numOfBids - tokenIdToAuction[_tokenId].numOfCanceledBids > 0;
    }

    function isValidBid(uint256 _tokenId, address _bidder) public view returns(bool) {
        Auction storage _auction = tokenIdToAuction[_tokenId];
        ERC20 _ERC20 = ERC20(_auction.tokenContract);

        return (_ERC20.balanceOf(_bidder) >= _auction.bids[_bidder].amount) &&
        (_ERC20.allowance(_bidder, address(this)) >= _auction.bids[_bidder].amount);
    }

    function getBids(uint256 _tokenId) public view returns (Bid[] memory) {
        Auction storage _auction = tokenIdToAuction[_tokenId];
        address[] storage bidders = tokenIdToAuction[_tokenId].bidders;
        Bid[] memory bids = new Bid[](bidders.length);

        for (uint256 i = 0; i < bidders.length; i++) {
            bids[i] = _auction.bids[bidders[i]];
        }
        return bids;
    }

}