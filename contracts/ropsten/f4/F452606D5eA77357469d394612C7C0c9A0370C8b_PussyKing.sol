pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract PussyKing is Initializable, ContextUpgradeable {
    using AddressUpgradeable for address;
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _pussyIdTracker;
    
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    struct Pussy {
        string Name;
        uint256 PussyId;
        address King;
    }

    struct Auction {
        bool IsStillInProgress;
        uint256 MinPrice;
        uint256 PussyId;
        uint256 AuctionEndTime;
        address OnlySellTo;
    }

    struct Offer {
        uint PussyId;
        uint Value;
        address Bidder;
    }
    
    bool private initialized;

    string private _baseTokenURI;
    string private _name;
    string private _symbol;
    address payable private _author;

    uint256 private _earnedEth;
    uint256 private _releasedEth;
    uint256 public _minBidStep;

    mapping(address => uint256) private _balances;

    mapping(uint256 => Pussy) private _pussies;
    mapping(uint256 => Auction) private _auctions;
    mapping(uint256 => Offer) private _offers;

    function initialize() public initializer {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        
        __Context_init();

        _minBidStep = 1 * (10 ** 18);

        _name = "PussyKing";
        _symbol = "PUSS";
        _baseTokenURI = "https://pussykingclub.com/";
        _author = payable(0x94BBbeD9d21EdE44753406A27B0aFd4825AC2ef2);
    }

    function ownerOf(uint256 pussyId) public view returns (address) {
        address king = _pussies[pussyId].King;
        require(king != address(0), "King query for nonexistent pussy");
        return king;
    }

    function balanceOf(address king) public view returns (uint256) {
        require(king != address(0), "Balance query for the zero king");
        return _balances[king];
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 pussyId) public view returns (string memory) {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId");

        return bytes(_baseTokenURI).length > 0 ? string(abi.encodePacked(_baseTokenURI, pussyId.toString())) : "";
    }
    
    function transferFrom(
        address from,
        address to,
        uint256 pussyId
    ) public {
        require(_msgSender() == from);
        require(ownerOf(pussyId) == from, "Transfer of pussy that is not own");
        require(to != address(0), "Transfer to the zero king");
        require(_auctions[pussyId].IsStillInProgress == false, "Auction is still in progress");

        _balances[from] -= 1;
        _balances[to] += 1;
        _pussies[pussyId].King = to;

        emit Transfer(from, to, pussyId);
    }

    function uploadPussy(string memory pussyName) public {
        require(_msgSender() == _author, "Method is available only to author");
        _pussyIdTracker.increment();
        uint256 pussyId = _pussyIdTracker.current();
        _pussies[pussyId] = Pussy(pussyName, pussyId, payable(address(0)));
    }
    
    function authorAuction(uint256 pussyId, uint256 startPrice, uint256 auctionTimeInDate) public {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId");
        Pussy memory pussy = _pussies[pussyId];
        require(pussy.King == address(0) && _msgSender() == _author, "Sender not author");

        startAuction(pussyId, startPrice, auctionTimeInDate, address(0));
    }

    function auctionPussy(uint256 pussyId, uint256 startPrice, uint256 auctionTimeInDate) public {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId");
        Pussy memory pussy = _pussies[pussyId];
        require(pussy.King == _msgSender(), "Sender not king of pussy");

        startAuction(pussyId, startPrice, auctionTimeInDate, address(0));
    }

    function offerPussyToAddress(uint256 pussyId, uint256 minPrice, uint256 offerEndTimeInDate, address sellTo) public {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId");
        require(sellTo != address(0), "Sell to zero address");
        Pussy memory pussy = _pussies[pussyId];
        require(pussy.King == _msgSender(), "Sender not king of pussy");

        startAuction(pussyId, minPrice, offerEndTimeInDate, sellTo);
    }

    function startAuction(uint256 pussyId, uint256 startPrice, uint256 auctionTimeInDate, address onlySellTo) private {
        require(startPrice >= 1 * (10 ** 18), "Min price 1 eth"); // more then 1 eth
        require(_auctions[pussyId].IsStillInProgress == false, "Auction is still in progress");
        require(auctionTimeInDate >= 1);

        uint256 auctionEndTime = block.timestamp + auctionTimeInDate * 60;
        _auctions[pussyId] = Auction(true, startPrice, pussyId, auctionEndTime, onlySellTo);
    }

    function pussyOf(uint256 pussyId) public view returns (string memory, uint256, address) {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId"); 
        Pussy memory pussy = _pussies[pussyId];
        return (pussy.Name, pussy.PussyId, pussy.King);
    }
    
    function auctionOf(uint256 pussyId) public view returns (bool, uint256, uint256, uint256, address ) {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId");
        Auction memory auction = _auctions[pussyId];
        return (auction.IsStillInProgress, auction.MinPrice, auction.PussyId, auction.AuctionEndTime, auction.OnlySellTo);
    }
    
    function offerOf(uint256 pussyId) public view returns (uint256,  uint256, address) {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId");
        Offer memory offer = _offers[pussyId];
        return (offer.PussyId, offer.Value, offer.Bidder);
    }

    function placeBid(uint256 pussyId) external payable {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId");

        Auction memory auction = _auctions[pussyId];
        require(auction.AuctionEndTime > block.timestamp, "Auction is over");
        require(auction.OnlySellTo == address(0) || auction.OnlySellTo == _msgSender());
        
        Offer storage offer = _offers[pussyId];
        require(msg.value > offer.Value + _minBidStep, "Insufficient price");

        if (offer.Bidder != address(0)) {
            AddressUpgradeable.sendValue(payable(offer.Bidder), offer.Value);
        }

        _offers[pussyId] = Offer(pussyId, msg.value, _msgSender());
    }

    function becomePussyKing(uint256 pussyId) external {
        require(_pussies[pussyId].PussyId != 0, "Invalid pussyId");

        Auction memory auction = _auctions[pussyId];
        require(auction.IsStillInProgress, "Auction is not still in progress");
        require(auction.AuctionEndTime < block.timestamp, "The auction is still in progress");

        Offer memory offer = _offers[pussyId];
        require(offer.Bidder != address(0), "Bidder is zero");


        Pussy memory pussy = _pussies[pussyId];
        uint256 authorReward = 0;
        address from = pussy.King;
        address to = offer.Bidder;
        if(from == address(0)){
            authorReward = offer.Value;
        } else {
            uint256 authorCommision = offer.Value / 10;
            AddressUpgradeable.sendValue(payable(from), offer.Value - authorCommision);
            authorReward = authorCommision;
            _balances[from] -= 1;
        }

        _earnedEth += authorReward;
        _balances[to] += 1;
        _pussies[pussyId] = Pussy(pussy.Name, pussyId, to);
        _offers[pussyId] = Offer(pussyId, 0, address(0));
        _auctions[pussyId] = Auction(false, 0, pussyId, 0, address(0));

        emit Transfer(from, to, pussyId);
    }

    function abortAuction(uint256 pussyId) external {
        require(_offers[pussyId].Bidder == address(0), "Has bid");
        address king = _pussies[pussyId].King;
        require(_msgSender() == king || (king == address(0) && _msgSender() == _author));
        _auctions[pussyId] = Auction(false, 0, pussyId, 0, address(0));
    }

    function releaseEarn() external {
        require(_msgSender() == _author, "Method is available only to author");
        uint256 currentRelease = _earnedEth - _releasedEth;
        require(currentRelease > 0, "currentRelease = 0"); 
        AddressUpgradeable.sendValue(_author, currentRelease);
        _releasedEth += currentRelease;
    }
}