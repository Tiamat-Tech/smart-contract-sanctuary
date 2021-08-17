pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract PuToken is ERC721 {
    struct Pussy {
        string Name;
        uint256 TokenId;
        uint256 Price;
        uint256 AuctionEndTime;
        address Bidder;
    }

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI;
    address payable private _admin;

    uint256 private _earnedEth;
    uint256 private _releasedEth;

    mapping(uint256 => Pussy) private _pussies;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        address payable admin
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        _admin = admin;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function uploadPussy(string memory name, uint256 startPrice, uint256 auctionEndTime) public {
        require(_msgSender() == _admin, "Method is available only to admin");
        _tokenIdTracker.increment();
        uint256 tokenId = _tokenIdTracker.current();
        _pussies[tokenId] = Pussy(name, tokenId, startPrice, auctionEndTime, payable(address(0)));
    }

    function pussyOf(uint256 tokenId) public view returns (string memory, uint256, uint256, uint256, address) {
        require(tokenId <= _tokenIdTracker.current(), "Invalid tokenId");
        Pussy memory pussy = _pussies[tokenId];
        return (pussy.Name, pussy.TokenId, pussy.Price, pussy.AuctionEndTime, pussy.Bidder);
    }

    function placeBid(uint256 tokenId) external payable {
        require(tokenId <= _tokenIdTracker.current(), "Invalid tokenId");
        Pussy memory pussy = _pussies[tokenId];
        require(pussy.AuctionEndTime > block.timestamp, "Auction is over");
        require(msg.value > pussy.Price, "Insufficient price");

        if (pussy.Bidder != address(0)) {
            Address.sendValue(payable(pussy.Bidder), pussy.Price);
        }
        _pussies[tokenId].Price = msg.value;
        _pussies[tokenId].Bidder = _msgSender();
    }

    function becomeAnOwner(uint256 tokenId) public virtual {
        require(tokenId <= _tokenIdTracker.current(), "Invalid tokenId");
        Pussy memory pussy = _pussies[tokenId];
        require(pussy.AuctionEndTime < block.timestamp, "The auction is still in progress");

        _earnedEth += pussy.Price;
        _mint(pussy.Bidder, tokenId);
    }

    function releaseEarn() public {
        require(_msgSender() == _admin, "Method is available only to admin");
        uint256 currentRelease = _earnedEth - _releasedEth;
        require(currentRelease > 0, "currentRelease = 0"); 
        Address.sendValue(_admin, currentRelease);
        _releasedEth += currentRelease;
    }
}